/*
 Navicat Premium Data Transfer

 Source Server         : 本地AI数据库
 Source Server Type    : MySQL
 Source Server Version : 80040 (8.0.40)
 Source Host           : localhost:3306
 Source Schema         : amt_agent_db

 Target Server Type    : MySQL
 Target Server Version : 80040 (8.0.40)
 File Encoding         : 65001

 Date: 15/04/2026 08:40:16
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for role_perm_map
-- ----------------------------
DROP TABLE IF EXISTS `role_perm_map`;
CREATE TABLE `role_perm_map`  (
  `role_id` int NOT NULL COMMENT '关联 sys_roles 表 ID',
  `perm_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '关联 sys_permissions 编码',
  PRIMARY KEY (`role_id`, `perm_code`) USING BTREE,
  CONSTRAINT `role_perm_map_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `sys_roles` (`role_id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '角色默认权限关联表（定义各职级基础权力包）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for sys_audit_log
-- ----------------------------
DROP TABLE IF EXISTS `sys_audit_log`;
CREATE TABLE `sys_audit_log`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '审计主键ID',
  `operator_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '操作人工号',
  `operator_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '操作人姓名',
  `conversation_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '关联对话Session ID',
  `action_type` enum('AUTH_GRANT','AUTH_REVOKE','USER_CREATE','DATA_EXPORT','SENSITIVE_QUERY') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '敏感操作类型枚举：授权、撤权、开户、导出、敏感查询',
  `target_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '操作目标ID（如被操作人的工号）',
  `detail_content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '操作行为的人类可读描述',
  `raw_tool_params` json NULL COMMENT '工具调用原始参数快照',
  `status` enum('SUCCESS','FAIL','INTERCEPTED') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT 'SUCCESS' COMMENT '操作状态：成功、失败、被系统拦截',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '审计记录生成时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 8 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统安全审计日志（记录高风险操作细节）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for sys_chat_history
-- ----------------------------
DROP TABLE IF EXISTS `sys_chat_history`;
CREATE TABLE `sys_chat_history`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '对话存储ID',
  `user_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT '所属用户工号',
  `conversation_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT '对话会话唯一ID',
  `messages` json NOT NULL COMMENT '完整对话链路(含Role, Content, Tool_Calls的JSON数组)',
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_conv`(`user_id` ASC, `conversation_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 373 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin COMMENT = 'AI对话上下文存储表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for sys_operation_log
-- ----------------------------
DROP TABLE IF EXISTS `sys_operation_log`;
CREATE TABLE `sys_operation_log`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '流水流水ID',
  `operator_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '执行人工号',
  `operator_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '执行人姓名',
  `module_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '所属业务模块（如：LINE_01, AUTH, STORAGE）',
  `action_cmd` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '具体指令（如：OPEN, CLOSE, QUERY）',
  `cmd_params` json NULL COMMENT '指令附带的原始参数',
  `exec_result` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '执行结果快照',
  `conversation_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '关联对话ID',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_operator`(`operator_id` ASC) USING BTREE,
  INDEX `idx_time`(`created_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 34 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '业务指令执行流水账（硬件/数据操作记录）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for sys_permissions
-- ----------------------------
DROP TABLE IF EXISTS `sys_permissions`;
CREATE TABLE `sys_permissions`  (
  `perm_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '权限唯一编码，如 line:01:ctrl',
  `perm_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '权限中文名称：如控制一号线',
  `category` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '所属分类：system-系统, data-数据, production-生产',
  `source_node` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT 'local',
  `source_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT 'local',
  `perm_desc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  PRIMARY KEY (`perm_code`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '功能权限原子定义表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for sys_roles
-- ----------------------------
DROP TABLE IF EXISTS `sys_roles`;
CREATE TABLE `sys_roles`  (
  `role_id` int NOT NULL COMMENT '角色唯一ID：1-开发, 2-管理, 3-用户',
  `role_name` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '角色英文标识：developer, admin, user',
  `weight` int NULL DEFAULT NULL COMMENT '权限权重：数值越大职级越高，用于越权校验',
  PRIMARY KEY (`role_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统角色职级定义表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for sys_users
-- ----------------------------
DROP TABLE IF EXISTS `sys_users`;
CREATE TABLE `sys_users`  (
  `employee_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '员工工号（主键，全局唯一）',
  `username` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '员工真实姓名',
  `role_id` int NULL DEFAULT NULL COMMENT '所属角色ID，关联 sys_roles',
  PRIMARY KEY (`employee_id`) USING BTREE,
  INDEX `role_id`(`role_id` ASC) USING BTREE,
  CONSTRAINT `sys_users_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `sys_roles` (`role_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统用户信息主表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_extra_perms
-- ----------------------------
DROP TABLE IF EXISTS `user_extra_perms`;
CREATE TABLE `user_extra_perms`  (
  `employee_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '关联 sys_users 员工工号',
  `perm_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '具体的权限编码',
  `action` enum('ALLOW','DENY') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '策略：ALLOW-额外授信, DENY-显式黑名单(优先级最高)',
  PRIMARY KEY (`employee_id`, `perm_code`) USING BTREE,
  CONSTRAINT `user_extra_perms_ibfk_1` FOREIGN KEY (`employee_id`) REFERENCES `sys_users` (`employee_id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户个性化特权/黑名单表（精细化控制核心）' ROW_FORMAT = Dynamic;

SET FOREIGN_KEY_CHECKS = 1;
