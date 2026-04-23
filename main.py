from datetime import datetime
import sys
import io
import uvicorn
import json
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pydantic_ai import Agent
from sqlalchemy import text
from pydantic_ai.messages import ModelMessagesTypeAdapter
from fastapi.responses import StreamingResponse

# 内部模块导入
from app.agent.factory import fetch_user_context, get_brain_model, is_complex_task
from app.agent.core import create_dynamic_agent, Deps
from app.agent.retriever import tool_retriever
from app.database.db_base import engine
from app.database.manager import sync_tools_to_db, sync_mcp_to_db

# ==========================================
# 1. 环境初始化
# ==========================================
if sys.platform.startswith('win'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

app = FastAPI(title="工业 AI 中枢 (标准化协议版)")


class ChatRequest(BaseModel):
    user_id: str
    conversation_id: str
    prompt: str


# ==========================================
# 2. 持久化层 (增强鲁棒性)
# ==========================================
def get_history_from_db(user_id: str, conv_id: str):
    try:
        with engine.connect() as conn:
            sql = text("SELECT messages FROM sys_chat_history WHERE user_id = :u AND conversation_id = :c")
            row = conn.execute(sql, {"u": user_id, "c": conv_id}).first()
            if not row or not row[0]: return []

            msgs = ModelMessagesTypeAdapter.validate_json(row[0]) if isinstance(row[0],
                                                                                str) else ModelMessagesTypeAdapter.validate_python(
                row[0])
            # ✨ 核心修复：清洗历史记录中的 None，防止 Ollama 过敏
            for m in msgs:
                if hasattr(m, 'content') and m.content is None:
                    m.content = ""
            return msgs
    except Exception as e:
        print(f"⚠️ [History-Load-Error]: {e}")
        return []


def save_history_to_db(user_id: str, conv_id: str, messages):
    try:
        m_json = ModelMessagesTypeAdapter.dump_json(messages).decode()
        with engine.connect() as conn:
            sql = text("""
                INSERT INTO sys_chat_history (user_id, conversation_id, messages) 
                VALUES (:u, :c, :m) 
                ON DUPLICATE KEY UPDATE messages = :m
            """)
            conn.execute(sql, {"u": user_id, "c": conv_id, "m": m_json})
            conn.commit()
    except Exception as e:
        print(f"❌ [History-Save-Error]: {e}")


# ==========================================
# 3. 核心路由接口
# ==========================================
@app.post("/chat")
async def chat_endpoint(req: ChatRequest):
    try:
        # 1. ⚡ 获取上下文（这里会包含我们刚才预装载的 permissions 字典）
        user_context = await fetch_user_context(req.user_id, req.conversation_id)

        # 2. 注入依赖
        deps = Deps(user=user_context)

        # 3. 这里的 create_dynamic_agent 内部现在已经实现了逻辑过滤
        dynamic_agent = await create_dynamic_agent(deps, req.prompt)

        # 4. 获取历史
        history = get_history_from_db(req.user_id, req.conversation_id)

    except PermissionError as e:
        # 明确是权限问题（如：工号不存在）
        print(f"🚫 访问拒绝: {str(e)}")
        raise HTTPException(status_code=403, detail=f"权限拒绝: {str(e)}")
    except Exception as e:
        # 其他系统崩溃问题
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"中枢初始化失败: {str(e)}")

    async def response_generator():
        def pack_json(t: str, content: str):
            return f"data: {json.dumps({'type': t, 'text': content}, ensure_ascii=False)}\n\n"

        try:
            yield pack_json('status', '⚡ 正在本地调取工业数据...')

            async with dynamic_agent.run_stream(req.prompt, deps=deps, message_history=history) as result:
                tool_output_raw = ""
                # ✨ 新逻辑：先收集工具输出，同时决定是否要“拦截”

                # 1. 监控消息流中的工具返回
                # 我们先不跑 stream_text，而是先等待工具执行完毕
                # Pydantic-AI 的工具执行在 stream 开启时就已经触发

                # 2. 提取工具原始数据（用于判断是否过长）
                for m in result.new_messages():
                    if hasattr(m, 'parts'):
                        for part in m.parts:
                            if hasattr(part, 'content') and part.content:
                                tool_output_raw += str(part.content)

                # --- 决策分支 ---
                DATA_THRESHOLD = 600
                if len(tool_output_raw) > DATA_THRESHOLD or is_complex_task(req.prompt):
                    # 🚀 情况 A：数据太长，掐断本地流，走云端大脑
                    yield pack_json('status', f'💡 数据较大({len(tool_output_raw)}字)，移交云端总结...')

                    brain_model = get_brain_model()
                    summary_agent = Agent(brain_model)
                    brain_prompt = f"问题：{req.prompt}\n\n原始数据：\n{tool_output_raw}\n\n请总结。"

                    async with summary_agent.run_stream(brain_prompt) as brain_result:
                        async for b_chunk in brain_result.stream_text():
                            yield pack_json('chunk', b_chunk)

                    save_history_to_db(req.user_id, req.conversation_id,
                                       history + result.new_messages() + brain_result.new_messages())

                else:
                    # ⚡ 情况 B：数据量小（比如查盖伦），直接让本地模型流式吐字
                    # 这样用户能看到本地模型实时生成的每一句话
                    async for chunk in result.stream_text():
                        yield pack_json('chunk', chunk)

                    save_history_to_db(req.user_id, req.conversation_id, history + result.new_messages())

            yield pack_json('done', '')

        except Exception as e:
            import traceback
            traceback.print_exc()
            yield pack_json('error', f'中枢调度故障：{str(e)}')

    return StreamingResponse(response_generator(), media_type="text/event-stream")


# ==========================================
# 4. 系统启动预热
# ==========================================
@app.on_event("startup")
async def startup_event():
    print("⚡ [INIT] 系统启动...")
    sync_tools_to_db()
    await sync_mcp_to_db()
    tool_retriever.refresh_index()
    print("✅ [READY] 工业 AI 平台就绪。")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5050)