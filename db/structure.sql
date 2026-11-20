
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!50717 SELECT COUNT(*) INTO @rocksdb_has_p_s_session_variables FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'session_variables' */;
/*!50717 SET @rocksdb_get_is_supported = IF (@rocksdb_has_p_s_session_variables, 'SELECT COUNT(*) INTO @rocksdb_is_supported FROM performance_schema.session_variables WHERE VARIABLE_NAME=\'rocksdb_bulk_load\'', 'SELECT 0') */;
/*!50717 PREPARE s FROM @rocksdb_get_is_supported */;
/*!50717 EXECUTE s */;
/*!50717 DEALLOCATE PREPARE s */;
/*!50717 SET @rocksdb_enable_bulk_load = IF (@rocksdb_is_supported, 'SET SESSION rocksdb_bulk_load = 1', 'SET @rocksdb_dummy_bulk_load = 0') */;
/*!50717 PREPARE s FROM @rocksdb_enable_bulk_load */;
/*!50717 EXECUTE s */;
/*!50717 DEALLOCATE PREPARE s */;
DROP TABLE IF EXISTS `active_storage_attachments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `active_storage_attachments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `record_type` varchar(255) NOT NULL,
  `record_id` varchar(36) NOT NULL,
  `blob_id` bigint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_active_storage_attachments_uniqueness` (`record_type`,`record_id`,`name`,`blob_id`),
  KEY `index_active_storage_attachments_on_blob_id` (`blob_id`),
  CONSTRAINT `fk_rails_c3b3935057` FOREIGN KEY (`blob_id`) REFERENCES `active_storage_blobs` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `active_storage_blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `active_storage_blobs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `key` varchar(255) NOT NULL,
  `filename` varchar(255) NOT NULL,
  `content_type` varchar(255) DEFAULT NULL,
  `metadata` text,
  `service_name` varchar(255) NOT NULL,
  `byte_size` bigint NOT NULL,
  `checksum` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_active_storage_blobs_on_key` (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `active_storage_variant_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `active_storage_variant_records` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `blob_id` bigint NOT NULL,
  `variation_digest` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_active_storage_variant_records_uniqueness` (`blob_id`,`variation_digest`),
  KEY `index_active_storage_variant_records_on_blob_id` (`blob_id`),
  CONSTRAINT `fk_rails_993965df05` FOREIGN KEY (`blob_id`) REFERENCES `active_storage_blobs` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `agent_proposals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `agent_proposals` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `agent_id` varchar(36) NOT NULL,
  `on_behalf_of_user_id` varchar(36) DEFAULT NULL,
  `kind` varchar(255) NOT NULL DEFAULT 'enrollment',
  `job_id` varchar(36) DEFAULT NULL,
  `person_id` varchar(36) NOT NULL,
  `sequence_id` varchar(36) NOT NULL,
  `mailbox_id` varchar(36) NOT NULL,
  `rediscovery_candidate_id` varchar(36) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'pending',
  `draft_opener` text,
  `final_opener` text,
  `rationale` json NOT NULL,
  `decided_by_user_id` varchar(36) DEFAULT NULL,
  `decided_at` datetime(6) DEFAULT NULL,
  `decision_reason` varchar(255) DEFAULT NULL,
  `enrollment_id` varchar(36) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_agent_proposals_tenant_pk` (`organization_id`,`id`),
  KEY `index_agent_proposals_queue` (`organization_id`,`status`,`created_at`),
  KEY `index_agent_proposals_person_sequence` (`organization_id`,`sequence_id`,`person_id`),
  KEY `fk_agent_proposals_agents_tenant` (`organization_id`,`agent_id`),
  KEY `fk_agent_proposals_people_tenant` (`organization_id`,`person_id`),
  KEY `fk_agent_proposals_mailboxes_tenant` (`organization_id`,`mailbox_id`),
  CONSTRAINT `fk_agent_proposals_agents_tenant` FOREIGN KEY (`organization_id`, `agent_id`) REFERENCES `agents` (`organization_id`, `id`),
  CONSTRAINT `fk_agent_proposals_mailboxes_tenant` FOREIGN KEY (`organization_id`, `mailbox_id`) REFERENCES `mailboxes` (`organization_id`, `id`),
  CONSTRAINT `fk_agent_proposals_organizations` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_agent_proposals_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `fk_agent_proposals_sequences_tenant` FOREIGN KEY (`organization_id`, `sequence_id`) REFERENCES `sequences` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `agents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `agents` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `owner_membership_id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` text,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `scopes` json NOT NULL,
  `created_by_user_id` varchar(36) DEFAULT NULL,
  `version` int NOT NULL DEFAULT '1',
  `paused_at` datetime(6) DEFAULT NULL,
  `revoked_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_agents_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_agents_owner_name` (`organization_id`,`owner_membership_id`,`name`),
  CONSTRAINT `fk_agents_memberships_tenant` FOREIGN KEY (`organization_id`, `owner_membership_id`) REFERENCES `memberships` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_b081040964` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `api_credentials`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `api_credentials` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `kind` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `token_prefix` varchar(16) NOT NULL,
  `token_digest` varchar(64) NOT NULL,
  `scopes` json NOT NULL,
  `user_id` varchar(36) DEFAULT NULL,
  `agent_id` varchar(36) DEFAULT NULL,
  `api_version` varchar(255) NOT NULL DEFAULT '2026-11-01',
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `expires_at` datetime(6) DEFAULT NULL,
  `last_used_at` datetime(6) DEFAULT NULL,
  `revoked_at` datetime(6) DEFAULT NULL,
  `created_by_user_id` varchar(36) DEFAULT NULL,
  `version` int NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_api_credentials_on_token_digest` (`token_digest`),
  UNIQUE KEY `index_api_credentials_tenant_pk` (`organization_id`,`id`),
  KEY `index_api_credentials_user` (`organization_id`,`user_id`),
  KEY `index_api_credentials_agent` (`organization_id`,`agent_id`),
  KEY `fk_rails_689eb16da8` (`user_id`),
  CONSTRAINT `fk_api_credentials_agents_tenant` FOREIGN KEY (`organization_id`, `agent_id`) REFERENCES `agents` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_689eb16da8` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_be4b4015d9` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `application_question_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `application_question_templates` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `owner_user_id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `questions` json NOT NULL,
  `version` int NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_question_templates_tenant` (`organization_id`,`id`),
  KEY `fk_rails_c46166f343` (`owner_user_id`),
  CONSTRAINT `fk_rails_c46166f343` FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_ebf54aa7f2` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `applications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `applications` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `job_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `pipeline_id` varchar(36) NOT NULL,
  `pipeline_version` int NOT NULL,
  `current_stage_key` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `source_project_member_id` varchar(36) DEFAULT NULL,
  `version` int NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `posting_id` varchar(36) DEFAULT NULL,
  `application_form_snapshot` json DEFAULT NULL,
  `application_answers` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_applications_tenant_pk` (`organization_id`,`id`),
  KEY `index_applications_on_organization_id_and_job_id` (`organization_id`,`job_id`),
  KEY `index_applications_on_organization_id_and_person_id` (`organization_id`,`person_id`),
  KEY `fk_applications_posting_tenant` (`organization_id`,`posting_id`),
  KEY `tenant_fk_395b6508a54ad360` (`organization_id`,`pipeline_id`),
  CONSTRAINT `fk_applications_jobs_tenant` FOREIGN KEY (`organization_id`, `job_id`) REFERENCES `jobs` (`organization_id`, `id`),
  CONSTRAINT `fk_applications_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `fk_applications_posting_tenant` FOREIGN KEY (`organization_id`, `posting_id`) REFERENCES `postings` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_618951e727` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_395b6508a54ad360` FOREIGN KEY (`organization_id`, `pipeline_id`) REFERENCES `pipelines` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `approval_policies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `approval_policies` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `applies_to` varchar(255) NOT NULL,
  `priority` int NOT NULL DEFAULT '0',
  `is_catch_all` tinyint(1) NOT NULL DEFAULT '0',
  `conditions` json DEFAULT NULL,
  `reapproval_fields` json DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_approval_policies_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_approval_policies_tenant_pk` (`organization_id`,`id`),
  KEY `index_approval_policies_match` (`organization_id`,`applies_to`,`priority`),
  CONSTRAINT `fk_rails_815d174ca9` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `approval_policy_steps`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `approval_policy_steps` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `approval_policy_id` varchar(36) NOT NULL,
  `position` int NOT NULL,
  `name` varchar(255) NOT NULL,
  `mode` varchar(255) NOT NULL DEFAULT 'sequential',
  `approvers` json NOT NULL,
  `require_mode` varchar(255) NOT NULL DEFAULT 'all',
  `step_when` json DEFAULT NULL,
  `if_no_approver` varchar(255) NOT NULL DEFAULT 'skip',
  `fallback_approver` varchar(255) DEFAULT NULL,
  `allow_self_approval` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_approval_policy_steps_position` (`organization_id`,`approval_policy_id`,`position`),
  UNIQUE KEY `index_approval_policy_steps_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_a4a322504d` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_6e056d957994899e` FOREIGN KEY (`organization_id`, `approval_policy_id`) REFERENCES `approval_policies` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `approvals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `approvals` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `entity_type` varchar(255) NOT NULL,
  `entity_id` varchar(36) NOT NULL,
  `entity_version_id` varchar(36) DEFAULT NULL,
  `approval_policy_id` varchar(36) DEFAULT NULL,
  `approval_policy_step_id` varchar(36) DEFAULT NULL,
  `step_key` varchar(255) DEFAULT NULL,
  `step_position` int DEFAULT NULL,
  `approver_user_id` varchar(36) DEFAULT NULL,
  `resolved_from` varchar(255) DEFAULT NULL,
  `requested_by_user_id` varchar(36) DEFAULT NULL,
  `requested_at` datetime(6) DEFAULT NULL,
  `approved_by_user_id` varchar(36) DEFAULT NULL,
  `approved_at` datetime(6) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'pending',
  `is_override` tinyint(1) NOT NULL DEFAULT '0',
  `reason` varchar(255) DEFAULT NULL,
  `metadata_json` json DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_approvals_tenant_pk` (`organization_id`,`id`),
  KEY `index_approvals_entity` (`organization_id`,`entity_type`,`entity_id`),
  KEY `index_approvals_approver` (`organization_id`,`approver_user_id`,`status`),
  KEY `tenant_fk_2c59543a76cadd81` (`organization_id`,`approval_policy_id`),
  KEY `tenant_fk_ad0e188ed02b3f95` (`organization_id`,`approval_policy_step_id`),
  CONSTRAINT `fk_rails_5aaa3a5e4a` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_2c59543a76cadd81` FOREIGN KEY (`organization_id`, `approval_policy_id`) REFERENCES `approval_policies` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_ad0e188ed02b3f95` FOREIGN KEY (`organization_id`, `approval_policy_step_id`) REFERENCES `approval_policy_steps` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ar_internal_metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ar_internal_metadata` (
  `key` varchar(255) NOT NULL,
  `value` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `audit_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_events` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `action` varchar(255) NOT NULL,
  `resource_type` varchar(255) NOT NULL,
  `resource_id` varchar(36) NOT NULL,
  `actor_id` varchar(36) DEFAULT NULL,
  `actor_type` varchar(255) DEFAULT NULL,
  `change_set` json DEFAULT NULL,
  `request_id` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `on_behalf_of_id` varchar(36) DEFAULT NULL,
  `credential_id` varchar(36) DEFAULT NULL,
  `source_surface` varchar(32) DEFAULT NULL,
  `api_version` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_audit_events_tenant_pk` (`organization_id`,`id`),
  KEY `index_audit_events_on_organization_id_and_created_at` (`organization_id`,`created_at`),
  CONSTRAINT `fk_rails_be0ed9e37f` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = latin1 */ ;
/*!50003 SET character_set_results = latin1 */ ;
/*!50003 SET collation_connection  = latin1_swedish_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017*/ /*!50003 TRIGGER `audit_events_no_update` BEFORE UPDATE ON `audit_events` FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_events is append-only';
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = latin1 */ ;
/*!50003 SET character_set_results = latin1 */ ;
/*!50003 SET collation_connection  = latin1_swedish_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017*/ /*!50003 TRIGGER `audit_events_no_delete` BEFORE DELETE ON `audit_events` FOR EACH ROW BEGIN
  IF COALESCE(@bigbuck_audit_purge, 0) <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_events is append-only';
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `availability_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `availability_requests` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `scheduling_link_id` varchar(36) NOT NULL,
  `candidate_time_zone` varchar(255) DEFAULT NULL,
  `windows` json DEFAULT NULL,
  `auto_book` tinyint(1) NOT NULL DEFAULT '0',
  `submitted_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_availability_requests_link` (`organization_id`,`scheduling_link_id`),
  UNIQUE KEY `index_availability_requests_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_675b396f80` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_ab4994c011021fd0` FOREIGN KEY (`organization_id`, `scheduling_link_id`) REFERENCES `scheduling_links` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `break_glass_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `break_glass_sessions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `opened_by_user_id` varchar(36) NOT NULL,
  `reason` varchar(255) NOT NULL,
  `kinds` json DEFAULT NULL,
  `opens_at` datetime(6) NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `closed_at` datetime(6) DEFAULT NULL,
  `reconciled_at` datetime(6) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'open',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_break_glass_sessions_tenant_pk` (`organization_id`,`id`),
  KEY `index_break_glass_sessions_status` (`organization_id`,`status`),
  CONSTRAINT `fk_rails_4f148715ea` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `calendar_connections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calendar_connections` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `kind` varchar(255) NOT NULL,
  `user_id` varchar(36) DEFAULT NULL,
  `calendar_id` varchar(255) NOT NULL,
  `secret_ref` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'connected',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_calendar_connections_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_b6a377a0f9` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `calendar_watch_channels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calendar_watch_channels` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `calendar_connection_id` varchar(36) NOT NULL,
  `calendar_id` varchar(255) NOT NULL,
  `channel_id` varchar(255) NOT NULL,
  `resource_id` varchar(255) DEFAULT NULL,
  `expires_at` datetime(6) NOT NULL,
  `sync_token` varchar(255) DEFAULT NULL,
  `last_synced_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_on_organization_id_channel_id_f42255e81f` (`organization_id`,`channel_id`),
  UNIQUE KEY `index_calendar_watch_channels_tenant_pk` (`organization_id`,`id`),
  KEY `tenant_fk_8c61d09131028f51` (`organization_id`,`calendar_connection_id`),
  CONSTRAINT `fk_rails_c91c3f26fc` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_8c61d09131028f51` FOREIGN KEY (`organization_id`, `calendar_connection_id`) REFERENCES `calendar_connections` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `communications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `communications` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `mailbox_id` varchar(36) DEFAULT NULL,
  `direction` varchar(255) NOT NULL,
  `channel` varchar(255) NOT NULL DEFAULT 'email',
  `subject` varchar(255) DEFAULT NULL,
  `body` text,
  `provider_message_id` varchar(255) DEFAULT NULL,
  `thread_id` varchar(255) DEFAULT NULL,
  `sequence_enrollment_id` varchar(36) DEFAULT NULL,
  `message_type` varchar(255) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'sent',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `rfc822_message_id` varchar(255) DEFAULT NULL,
  `in_reply_to` varchar(255) DEFAULT NULL,
  `sent_by_user_id` varchar(36) DEFAULT NULL,
  `agent_id` varchar(36) DEFAULT NULL,
  `on_behalf_of_user_id` varchar(36) DEFAULT NULL,
  `classification` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_communications_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_communications_provider_msg` (`organization_id`,`provider_message_id`),
  KEY `index_communications_person` (`organization_id`,`person_id`,`created_at`),
  KEY `tenant_fk_4a1666b0a6ae6da6` (`organization_id`,`mailbox_id`),
  KEY `index_communications_rfc822` (`organization_id`,`rfc822_message_id`),
  KEY `index_communications_thread` (`organization_id`,`thread_id`),
  CONSTRAINT `fk_communications_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_f74b43ef09` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_4a1666b0a6ae6da6` FOREIGN KEY (`organization_id`, `mailbox_id`) REFERENCES `mailboxes` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `companies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `companies` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `normalized_name` varchar(255) NOT NULL,
  `domain` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `industry` varchar(255) DEFAULT NULL,
  `employee_band` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_companies_tenant_pk` (`organization_id`,`id`),
  KEY `index_companies_on_organization_id_and_normalized_name` (`organization_id`,`normalized_name`),
  CONSTRAINT `fk_rails_206ba22f2a` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `compliance_policies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compliance_policies` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `priority` int NOT NULL DEFAULT '0',
  `is_fallback` tinyint(1) NOT NULL DEFAULT '0',
  `conditions` json DEFAULT NULL,
  `requirements` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_compliance_policies_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_compliance_policies_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_be47141563` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `config_objects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `config_objects` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `kind` varchar(255) NOT NULL,
  `key` varchar(255) NOT NULL,
  `spec` json NOT NULL,
  `version` int NOT NULL DEFAULT '1',
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_config_objects_on_organization_id_and_kind_and_key` (`organization_id`,`kind`,`key`),
  UNIQUE KEY `index_config_objects_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_cf8b50286c` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `config_plans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `config_plans` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'open',
  `desired_manifest` json NOT NULL,
  `change_set` json NOT NULL,
  `object_versions` json NOT NULL,
  `manifest_hash` varchar(255) NOT NULL,
  `refuse_reason` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_config_plans_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_22e88c9c78` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `config_revisions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `config_revisions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `number` int NOT NULL,
  `source` varchar(255) NOT NULL DEFAULT 'api',
  `actor_id` varchar(36) DEFAULT NULL,
  `manifest_hash` varchar(255) NOT NULL,
  `manifest` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_config_revisions_on_organization_id_and_number` (`organization_id`,`number`),
  UNIQUE KEY `index_config_revisions_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_b7546f3400` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `consent_purposes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `consent_purposes` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `label` varchar(255) NOT NULL,
  `lawful_basis` varchar(255) NOT NULL,
  `description` text,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_consent_purposes_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_consent_purposes_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_fef09446d4` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `consents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `consents` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `consent_purpose_id` varchar(36) NOT NULL,
  `notice_version_id` varchar(36) DEFAULT NULL,
  `compliance_policy_id` varchar(36) DEFAULT NULL,
  `lawful_basis` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL,
  `captured_via` varchar(255) NOT NULL,
  `captured_at` datetime(6) NOT NULL,
  `expires_at` datetime(6) DEFAULT NULL,
  `ip_address` varchar(255) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `evidence_json` json DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_consents_tenant_pk` (`organization_id`,`id`),
  KEY `index_consents_current` (`organization_id`,`person_id`,`consent_purpose_id`,`captured_at`),
  KEY `tenant_fk_8b4bb495a35ff0fb` (`organization_id`,`compliance_policy_id`),
  KEY `tenant_fk_5ee09a091aab3b56` (`organization_id`,`consent_purpose_id`),
  KEY `tenant_fk_e404d4e3ab54e0cc` (`organization_id`,`notice_version_id`),
  CONSTRAINT `fk_rails_0c0e527d61` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_30ad0e115609459b` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_5ee09a091aab3b56` FOREIGN KEY (`organization_id`, `consent_purpose_id`) REFERENCES `consent_purposes` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_8b4bb495a35ff0fb` FOREIGN KEY (`organization_id`, `compliance_policy_id`) REFERENCES `compliance_policies` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_e404d4e3ab54e0cc` FOREIGN KEY (`organization_id`, `notice_version_id`) REFERENCES `notice_versions` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `custom_field_values`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `custom_field_values` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `custom_field_id` varchar(36) NOT NULL,
  `entity_type` varchar(255) NOT NULL,
  `entity_id` varchar(36) NOT NULL,
  `value_text` text,
  `value_number` decimal(18,4) DEFAULT NULL,
  `value_date` date DEFAULT NULL,
  `value_json` json DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `field_version` int NOT NULL DEFAULT '1',
  `version` int NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_custom_field_values_unique` (`organization_id`,`custom_field_id`,`entity_type`,`entity_id`),
  UNIQUE KEY `index_custom_field_values_tenant_pk` (`organization_id`,`id`),
  KEY `fk_rails_e73dfaa201` (`custom_field_id`),
  KEY `index_custom_field_values_entity` (`organization_id`,`entity_type`,`entity_id`),
  CONSTRAINT `fk_rails_8f988b425b` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_rails_e73dfaa201` FOREIGN KEY (`custom_field_id`) REFERENCES `custom_fields` (`id`),
  CONSTRAINT `tenant_fk_e831d2a16c0ae6f8` FOREIGN KEY (`organization_id`, `custom_field_id`) REFERENCES `custom_fields` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `custom_field_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `custom_field_versions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `custom_field_id` varchar(36) NOT NULL,
  `version` int NOT NULL,
  `change_kind` varchar(255) NOT NULL,
  `definition` json NOT NULL,
  `migration_summary` json DEFAULT NULL,
  `actor_id` varchar(36) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_custom_field_versions_unique` (`organization_id`,`custom_field_id`,`version`),
  UNIQUE KEY `index_custom_field_versions_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_custom_field_versions_fields_tenant` FOREIGN KEY (`organization_id`, `custom_field_id`) REFERENCES `custom_fields` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_c3303191a2` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `custom_fields`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `custom_fields` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `entity` varchar(255) NOT NULL,
  `key` varchar(255) NOT NULL,
  `label` varchar(255) NOT NULL,
  `field_type` varchar(255) NOT NULL,
  `data_class` varchar(255) NOT NULL DEFAULT 'internal',
  `visibility_roles` json DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `requires_reapproval` tinyint(1) NOT NULL DEFAULT '0',
  `description` text,
  `options` json DEFAULT NULL,
  `reference_type` varchar(255) DEFAULT NULL,
  `required` tinyint(1) NOT NULL DEFAULT '0',
  `filterable` tinyint(1) NOT NULL DEFAULT '0',
  `display_order` int NOT NULL DEFAULT '0',
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `version` int NOT NULL DEFAULT '1',
  `archived_at` datetime(6) DEFAULT NULL,
  `show_on_apply` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_custom_fields_on_organization_id_and_entity_and_key` (`organization_id`,`entity`,`key`),
  UNIQUE KEY `index_custom_fields_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_e6e49694ee` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `data_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `data_requests` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) DEFAULT NULL,
  `kind` varchar(255) NOT NULL,
  `requester_email` varchar(255) DEFAULT NULL,
  `received_at` datetime(6) NOT NULL,
  `due_at` datetime(6) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'open',
  `completed_at` datetime(6) DEFAULT NULL,
  `assigned_user_id` varchar(36) DEFAULT NULL,
  `compliance_policy_id` varchar(36) DEFAULT NULL,
  `outcome_note` text,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_data_requests_tenant_pk` (`organization_id`,`id`),
  KEY `index_data_requests_open` (`organization_id`,`status`,`due_at`),
  KEY `tenant_fk_6f072855d1071821` (`organization_id`,`person_id`),
  CONSTRAINT `fk_rails_3ce004e632` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_6f072855d1071821` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `demo_sandboxes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `demo_sandboxes` (
  `surface` varchar(12) NOT NULL,
  `organization_id` varchar(36) DEFAULT NULL,
  `generation` int NOT NULL DEFAULT '1',
  `state` varchar(255) NOT NULL DEFAULT 'initializing',
  `seeded_at` datetime(6) DEFAULT NULL,
  `resets_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`surface`),
  UNIQUE KEY `index_demo_sandboxes_on_organization_id` (`organization_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `demo_template_snapshots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `demo_template_snapshots` (
  `key` varchar(32) NOT NULL,
  `fingerprint` varchar(64) NOT NULL,
  `seeded_at` datetime(6) NOT NULL,
  `payload` longblob NOT NULL,
  `blob_ids` json DEFAULT NULL,
  `row_count` int NOT NULL DEFAULT '0',
  `byte_size` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `dimension_values`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dimension_values` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `dimension_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `label` varchar(255) NOT NULL,
  `parent_id` varchar(36) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `position` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `attributes_json` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_dimension_values_key` (`organization_id`,`dimension_id`,`key`),
  UNIQUE KEY `index_dimension_values_tenant_pk` (`organization_id`,`id`),
  KEY `fk_rails_a8c043a636` (`dimension_id`),
  KEY `tenant_fk_0a5431058d9ccc63` (`organization_id`,`parent_id`),
  CONSTRAINT `fk_rails_a8c043a636` FOREIGN KEY (`dimension_id`) REFERENCES `dimensions` (`id`),
  CONSTRAINT `fk_rails_eb09c11e0b` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_0a5431058d9ccc63` FOREIGN KEY (`organization_id`, `parent_id`) REFERENCES `dimension_values` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_723c610bedea9def` FOREIGN KEY (`organization_id`, `dimension_id`) REFERENCES `dimensions` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `dimensions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dimensions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `label` varchar(255) NOT NULL,
  `hierarchical` tinyint(1) NOT NULL DEFAULT '0',
  `system` tinyint(1) NOT NULL DEFAULT '0',
  `applies_to` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_dimensions_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_dimensions_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_8476c85ad2` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `dnc_companies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dnc_companies` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `company_id` varchar(36) DEFAULT NULL,
  `domain` varchar(255) DEFAULT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_dnc_companies_tenant_pk` (`organization_id`,`id`),
  KEY `index_dnc_companies_on_organization_id_and_company_id` (`organization_id`,`company_id`),
  KEY `index_dnc_companies_on_organization_id_and_domain` (`organization_id`,`domain`),
  CONSTRAINT `fk_rails_df17eb07d2` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_a8720ee1fc0833f9` FOREIGN KEY (`organization_id`, `company_id`) REFERENCES `companies` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `documents` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `filename` varchar(255) NOT NULL,
  `content_type` varchar(255) NOT NULL,
  `byte_size` bigint NOT NULL,
  `checksum` varchar(255) NOT NULL,
  `storage_key` varchar(255) NOT NULL,
  `scan_status` varchar(255) NOT NULL DEFAULT 'pending',
  `visibility` varchar(255) NOT NULL DEFAULT 'internal',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `superseded_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_documents_tenant_pk` (`organization_id`,`id`),
  KEY `index_documents_on_organization_id_and_person_id` (`organization_id`,`person_id`),
  KEY `index_documents_on_organization_id_and_scan_status` (`organization_id`,`scan_status`),
  CONSTRAINT `fk_documents_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_38b1cebf1f` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `entity_dimension_values`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `entity_dimension_values` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `entity_type` varchar(255) NOT NULL,
  `entity_id` varchar(36) NOT NULL,
  `dimension_id` varchar(36) NOT NULL,
  `dimension_value_id` varchar(36) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_entity_dimension_values_unique` (`organization_id`,`entity_type`,`entity_id`,`dimension_id`,`dimension_value_id`),
  UNIQUE KEY `index_entity_dim_values_tenant_pk` (`organization_id`,`id`),
  KEY `tenant_fk_df722ea6d9dde075` (`organization_id`,`dimension_id`),
  KEY `tenant_fk_c308f07c1f30415d` (`organization_id`,`dimension_value_id`),
  CONSTRAINT `fk_rails_5972d7b46e` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_c308f07c1f30415d` FOREIGN KEY (`organization_id`, `dimension_value_id`) REFERENCES `dimension_values` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_df722ea6d9dde075` FOREIGN KEY (`organization_id`, `dimension_id`) REFERENCES `dimensions` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `hiring_team_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hiring_team_members` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `hiring_team_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `team_role` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_hiring_team_members_unique` (`organization_id`,`hiring_team_id`,`user_id`,`team_role`),
  UNIQUE KEY `index_hiring_team_members_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_e7a6db6c7f` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_02da19d1079000c2` FOREIGN KEY (`organization_id`, `hiring_team_id`) REFERENCES `hiring_teams` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `hiring_teams`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hiring_teams` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `job_id` varchar(36) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_hiring_teams_on_organization_id_and_job_id` (`organization_id`,`job_id`),
  UNIQUE KEY `index_hiring_teams_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_be6f96455f` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_e39e7c51426d854c` FOREIGN KEY (`organization_id`, `job_id`) REFERENCES `jobs` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `holidays`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `holidays` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `observed_on` date NOT NULL,
  `location_key` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_holidays_tenant_pk` (`organization_id`,`id`),
  KEY `index_holidays_on_day` (`organization_id`,`observed_on`,`location_key`),
  CONSTRAINT `fk_rails_1afd2ce622` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `idempotency_keys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `idempotency_keys` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `request_path` varchar(255) NOT NULL,
  `request_method` varchar(255) NOT NULL,
  `response_status` int NOT NULL,
  `response_body` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `request_fingerprint` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_idempotency_keys_on_organization_id_and_key` (`organization_id`,`key`),
  KEY `index_idempotency_keys_created_at` (`created_at`),
  CONSTRAINT `fk_rails_149452d765` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `import_rows`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `import_rows` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `import_run_id` varchar(36) NOT NULL,
  `row_number` int NOT NULL,
  `source_id` varchar(255) DEFAULT NULL,
  `resource_type` varchar(255) DEFAULT NULL,
  `resource_id` varchar(36) DEFAULT NULL,
  `raw` json DEFAULT NULL,
  `mapped` json DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'pending',
  `error_message` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_import_rows_number` (`organization_id`,`import_run_id`,`row_number`),
  UNIQUE KEY `index_import_rows_tenant_pk` (`organization_id`,`id`),
  KEY `index_import_rows_run_status` (`import_run_id`,`status`),
  CONSTRAINT `fk_rails_0ef993a23a` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_0888ff34a95686b9` FOREIGN KEY (`organization_id`, `import_run_id`) REFERENCES `import_runs` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `import_runs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `import_runs` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `source` varchar(255) NOT NULL DEFAULT 'csv',
  `entity` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'pending',
  `field_mapping` json NOT NULL,
  `row_count` int NOT NULL DEFAULT '0',
  `created_count` int NOT NULL DEFAULT '0',
  `updated_count` int NOT NULL DEFAULT '0',
  `error_count` int NOT NULL DEFAULT '0',
  `errors_json` json DEFAULT NULL,
  `actor_id` varchar(36) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `processed_count` int NOT NULL DEFAULT '0',
  `finished_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_import_runs_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_335672e6bc` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `interviewer_blocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interviewer_blocks` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `starts_at` datetime(6) NOT NULL,
  `ends_at` datetime(6) NOT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_interviewer_blocks_tenant_pk` (`organization_id`,`id`),
  KEY `index_interviewer_blocks_user` (`organization_id`,`user_id`,`starts_at`),
  CONSTRAINT `fk_rails_35fe8ccd27` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `interviewer_pool_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interviewer_pool_members` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `interviewer_pool_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `trainee` tinyint(1) NOT NULL DEFAULT '0',
  `paused` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_pool_members_unique` (`organization_id`,`interviewer_pool_id`,`user_id`),
  UNIQUE KEY `index_pool_members_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_83401ee61f` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_ed7de85efb4ef18e` FOREIGN KEY (`organization_id`, `interviewer_pool_id`) REFERENCES `interviewer_pools` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `interviewer_pools`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interviewer_pools` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_interviewer_pools_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_interviewer_pools_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_8d784b9bdf` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `interviewer_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interviewer_profiles` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `time_zone` varchar(255) NOT NULL DEFAULT 'UTC',
  `working_hours` json NOT NULL,
  `daily_limit` int NOT NULL DEFAULT '4',
  `weekly_limit` int NOT NULL DEFAULT '15',
  `buffer_minutes` int NOT NULL DEFAULT '15',
  `paused` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_interviewer_profiles_on_organization_id_and_user_id` (`organization_id`,`user_id`),
  UNIQUE KEY `index_interviewer_profiles_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_f45b45652e` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `interviews`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interviews` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `application_id` varchar(36) NOT NULL,
  `stage_key` varchar(255) NOT NULL,
  `interview_key` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'requested',
  `starts_at` datetime(6) DEFAULT NULL,
  `ends_at` datetime(6) DEFAULT NULL,
  `calendar_event_id` varchar(255) DEFAULT NULL,
  `interviewer_user_ids` json DEFAULT NULL,
  `on_decline` varchar(255) NOT NULL DEFAULT 'replace_from_pool',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `interviewer_pool_id` varchar(36) DEFAULT NULL,
  `needs_attention_reason` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_interviews_tenant_pk` (`organization_id`,`id`),
  KEY `index_interviews_application` (`organization_id`,`application_id`,`stage_key`,`interview_key`),
  CONSTRAINT `fk_interviews_applications_tenant` FOREIGN KEY (`organization_id`, `application_id`) REFERENCES `applications` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_1f80a78ff5` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobs` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `title` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'draft',
  `pipeline_id` varchar(36) NOT NULL,
  `confidential` tinyint(1) NOT NULL DEFAULT '0',
  `code_name` varchar(255) DEFAULT NULL,
  `version` int NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `requisition_id` varchar(36) DEFAULT NULL,
  `openings` int NOT NULL DEFAULT '1',
  `careers_visibility` varchar(255) NOT NULL DEFAULT 'public',
  `criteria` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_jobs_tenant_pk` (`organization_id`,`id`),
  KEY `index_jobs_on_organization_id_and_status` (`organization_id`,`status`),
  KEY `fk_jobs_pipelines_tenant` (`organization_id`,`pipeline_id`),
  KEY `index_jobs_on_organization_id_and_requisition_id` (`organization_id`,`requisition_id`),
  CONSTRAINT `fk_jobs_pipelines_tenant` FOREIGN KEY (`organization_id`, `pipeline_id`) REFERENCES `pipelines` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_6861f589d1` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_ca51d1a68967b44f` FOREIGN KEY (`organization_id`, `requisition_id`) REFERENCES `requisitions` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `legal_holds`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `legal_holds` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `subject_type` varchar(255) NOT NULL,
  `subject_id` varchar(36) NOT NULL,
  `reason` varchar(255) NOT NULL,
  `placed_by_user_id` varchar(36) NOT NULL,
  `placed_at` datetime(6) NOT NULL,
  `released_by_user_id` varchar(36) DEFAULT NULL,
  `released_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_legal_holds_tenant_pk` (`organization_id`,`id`),
  KEY `index_legal_holds_subject` (`organization_id`,`subject_type`,`subject_id`),
  CONSTRAINT `fk_rails_5099af0b83` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mailboxes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mailboxes` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `kind` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `user_id` varchar(36) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'connected',
  `daily_send_count` int NOT NULL DEFAULT '0',
  `daily_send_on` date DEFAULT NULL,
  `daily_cap` int NOT NULL DEFAULT '2000',
  `secret_ref` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `provider` varchar(255) NOT NULL DEFAULT 'gmail',
  `history_cursor` varchar(255) DEFAULT NULL,
  `watch_expires_at` datetime(6) DEFAULT NULL,
  `last_sync_status` varchar(255) DEFAULT NULL,
  `last_synced_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_mailboxes_on_organization_id_and_email` (`organization_id`,`email`),
  UNIQUE KEY `index_mailboxes_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_8015024bbf` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `membership_scopes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `membership_scopes` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `membership_id` varchar(36) NOT NULL,
  `dimension_id` varchar(36) NOT NULL,
  `dimension_value_id` varchar(36) NOT NULL,
  `include_descendants` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_membership_scopes_tenant_pk` (`organization_id`,`id`),
  KEY `index_membership_scopes_membership` (`organization_id`,`membership_id`),
  KEY `fk_rails_9f28dc453f` (`membership_id`),
  KEY `tenant_fk_ab5dcb368851eddf` (`organization_id`,`dimension_id`),
  KEY `tenant_fk_440d74ed3eeb4182` (`organization_id`,`dimension_value_id`),
  CONSTRAINT `fk_rails_9f28dc453f` FOREIGN KEY (`membership_id`) REFERENCES `memberships` (`id`),
  CONSTRAINT `fk_rails_bee7e2d2e7` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_440d74ed3eeb4182` FOREIGN KEY (`organization_id`, `dimension_value_id`) REFERENCES `dimension_values` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_580fc6325101feac` FOREIGN KEY (`organization_id`, `membership_id`) REFERENCES `memberships` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_ab5dcb368851eddf` FOREIGN KEY (`organization_id`, `dimension_id`) REFERENCES `dimensions` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `memberships`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `memberships` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `role_id` varchar(36) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_memberships_on_organization_id_and_user_id` (`organization_id`,`user_id`),
  UNIQUE KEY `index_memberships_tenant_pk` (`organization_id`,`id`),
  KEY `fk_rails_99326fb65d` (`user_id`),
  KEY `fk_rails_ab987c7623` (`role_id`),
  KEY `tenant_fk_a251ebe35054b2ca` (`organization_id`,`role_id`),
  CONSTRAINT `fk_rails_64267aab58` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_rails_99326fb65d` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_ab987c7623` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`),
  CONSTRAINT `tenant_fk_a251ebe35054b2ca` FOREIGN KEY (`organization_id`, `role_id`) REFERENCES `roles` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `merge_suggestions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `merge_suggestions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_a_id` varchar(36) NOT NULL,
  `person_b_id` varchar(36) NOT NULL,
  `reason` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'open',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_merge_suggestions_pair` (`organization_id`,`person_a_id`,`person_b_id`),
  UNIQUE KEY `index_merge_suggestions_tenant_pk` (`organization_id`,`id`),
  KEY `tenant_fk_26a73284e5c48959` (`organization_id`,`person_b_id`),
  CONSTRAINT `fk_rails_6dc37a29c5` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_26a73284e5c48959` FOREIGN KEY (`organization_id`, `person_b_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_d466529e6cc16a6c` FOREIGN KEY (`organization_id`, `person_a_id`) REFERENCES `people` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `message_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_templates` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `message_type` varchar(255) NOT NULL,
  `locale` varchar(255) NOT NULL DEFAULT 'en',
  `subject` varchar(255) NOT NULL,
  `body` text NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `archived_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_message_templates_on_organization_id_and_key_and_locale` (`organization_id`,`key`,`locale`),
  UNIQUE KEY `index_message_templates_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_0377aa3d91` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `notice_receipts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notice_receipts` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `notice_version_id` varchar(36) NOT NULL,
  `shown_via` varchar(255) NOT NULL,
  `locale` varchar(255) NOT NULL,
  `ip_address` varchar(255) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `shown_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_notice_receipts_tenant_pk` (`organization_id`,`id`),
  KEY `index_notice_receipts_person` (`organization_id`,`person_id`,`notice_version_id`),
  KEY `tenant_fk_479bb9ac098e51e6` (`organization_id`,`notice_version_id`),
  CONSTRAINT `fk_rails_83b136df17` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_479bb9ac098e51e6` FOREIGN KEY (`organization_id`, `notice_version_id`) REFERENCES `notice_versions` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_e2d01ec0dfebf0b0` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `notice_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notice_versions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `notice_id` varchar(36) NOT NULL,
  `version_number` int NOT NULL,
  `locale` varchar(255) NOT NULL,
  `body` text NOT NULL,
  `body_sha256` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_notice_versions_unique` (`organization_id`,`notice_id`,`version_number`,`locale`),
  UNIQUE KEY `index_notice_versions_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_2720ed4c85` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_c4440c8a0524943d` FOREIGN KEY (`organization_id`, `notice_id`) REFERENCES `notices` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `notices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notices` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `renotify` varchar(255) NOT NULL DEFAULT 'on-next-contact',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_notices_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_notices_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_42a2855ad4` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `oauth_identities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `oauth_identities` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `membership_id` varchar(36) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `issuer` varchar(255) NOT NULL,
  `subject` varchar(255) NOT NULL,
  `client_id` varchar(255) NOT NULL,
  `binding_digest` varchar(64) NOT NULL,
  `kind` varchar(255) NOT NULL,
  `scopes` json NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `revoked_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_identities_on_binding_digest` (`binding_digest`),
  UNIQUE KEY `index_oauth_identities_on_organization_id_and_id` (`organization_id`,`id`),
  KEY `fk_oauth_identity_membership_tenant` (`organization_id`,`membership_id`),
  CONSTRAINT `fk_oauth_identity_membership_tenant` FOREIGN KEY (`organization_id`, `membership_id`) REFERENCES `memberships` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_ff4381267b` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `oauth_transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `oauth_transactions` (
  `id` varchar(36) NOT NULL,
  `state_digest` varchar(64) NOT NULL,
  `browser_digest` varchar(64) NOT NULL,
  `payload` json NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_transactions_on_state_digest` (`state_digest`),
  KEY `index_oauth_transactions_on_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `offer_documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `offer_documents` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `offer_version_id` varchar(36) NOT NULL,
  `kind` varchar(255) NOT NULL,
  `body_html` text,
  `sha256` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_offer_documents_tenant_pk` (`organization_id`,`id`),
  KEY `index_offer_documents_version` (`organization_id`,`offer_version_id`,`kind`),
  CONSTRAINT `fk_rails_477d9594ae` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_9aab7c807e11c311` FOREIGN KEY (`organization_id`, `offer_version_id`) REFERENCES `offer_versions` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `offer_responses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `offer_responses` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `offer_version_id` varchar(36) NOT NULL,
  `response` varchar(255) NOT NULL,
  `responded_by` varchar(255) NOT NULL,
  `recorded_by_user_id` varchar(36) DEFAULT NULL,
  `reason_key` varchar(255) DEFAULT NULL,
  `note` text,
  `document_sha256` varchar(255) DEFAULT NULL,
  `ip_address` varchar(255) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `link_sent_to_email` varchar(255) DEFAULT NULL,
  `typed_name` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_offer_responses_on_organization_id_and_offer_version_id` (`organization_id`,`offer_version_id`),
  UNIQUE KEY `index_offer_responses_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_11239d61a6` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_f094b97f4f716951` FOREIGN KEY (`organization_id`, `offer_version_id`) REFERENCES `offer_versions` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `offer_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `offer_templates` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `format` varchar(255) NOT NULL DEFAULT 'html',
  `body` text NOT NULL,
  `available_for` json DEFAULT NULL,
  `expires_after_days` int NOT NULL DEFAULT '7',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_offer_templates_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_offer_templates_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_f1c121c636` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `offer_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `offer_versions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `offer_id` varchar(36) NOT NULL,
  `version_number` int NOT NULL,
  `fields` json NOT NULL,
  `approval_policy_id` varchar(36) DEFAULT NULL,
  `approval_state` varchar(255) NOT NULL DEFAULT 'not_required',
  `supersedes_version_id` varchar(36) DEFAULT NULL,
  `created_by_type` varchar(255) NOT NULL DEFAULT 'User',
  `created_by_id` varchar(36) DEFAULT NULL,
  `sent_at` datetime(6) DEFAULT NULL,
  `expires_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `offer_template_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_offer_versions_number` (`organization_id`,`offer_id`,`version_number`),
  UNIQUE KEY `index_offer_versions_tenant_pk` (`organization_id`,`id`),
  KEY `tenant_fk_4064bfab776ce0a5` (`organization_id`,`approval_policy_id`),
  KEY `tenant_fk_8b296dfe014cb455` (`organization_id`,`offer_template_id`),
  CONSTRAINT `fk_rails_b22ecfb5cc` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_4064bfab776ce0a5` FOREIGN KEY (`organization_id`, `approval_policy_id`) REFERENCES `approval_policies` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_8b296dfe014cb455` FOREIGN KEY (`organization_id`, `offer_template_id`) REFERENCES `offer_templates` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_a464ce3e0f6e9bec` FOREIGN KEY (`organization_id`, `offer_id`) REFERENCES `offers` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `offers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `offers` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `application_id` varchar(36) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'draft',
  `current_version_id` varchar(36) DEFAULT NULL,
  `rescind_reason_key` varchar(255) DEFAULT NULL,
  `live_key` varchar(36) DEFAULT NULL,
  `version` int NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `checklist` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_offers_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_offers_one_live` (`organization_id`,`live_key`),
  KEY `index_offers_on_organization_id_and_application_id` (`organization_id`,`application_id`),
  KEY `tenant_fk_94cb76111d7d43d3` (`organization_id`,`current_version_id`),
  CONSTRAINT `fk_offers_applications_tenant` FOREIGN KEY (`organization_id`, `application_id`) REFERENCES `applications` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_16e70cd36f` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_94cb76111d7d43d3` FOREIGN KEY (`organization_id`, `current_version_id`) REFERENCES `offer_versions` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `opt_outs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `opt_outs` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) DEFAULT NULL,
  `email_digest` varchar(255) NOT NULL,
  `source` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_opt_outs_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_opt_outs_digest` (`organization_id`,`email_digest`),
  KEY `fk_opt_outs_people_tenant` (`organization_id`,`person_id`),
  CONSTRAINT `fk_opt_outs_organizations` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_opt_outs_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `organizations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `organizations` (
  `id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `slug` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `settings` json DEFAULT NULL,
  `repository_lock` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_organizations_on_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `outbox_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `outbox_events` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `event_type` varchar(255) NOT NULL,
  `resource_type` varchar(255) NOT NULL,
  `resource_id` varchar(36) NOT NULL,
  `payload` json NOT NULL,
  `subject_version` int DEFAULT NULL,
  `delivered_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `api_version` varchar(32) DEFAULT NULL,
  `actor_type` varchar(32) DEFAULT NULL,
  `actor_id` varchar(36) DEFAULT NULL,
  `source_surface` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_outbox_events_tenant_pk` (`organization_id`,`id`),
  KEY `index_outbox_events_on_delivered_at_and_created_at` (`delivered_at`,`created_at`),
  CONSTRAINT `fk_rails_b6cb24ddb3` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `outreach_snapshots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `outreach_snapshots` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `snapshot_on` date NOT NULL,
  `sequence_id` varchar(36) DEFAULT NULL,
  `scope_key` varchar(40) NOT NULL,
  `metrics` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_outreach_snapshots_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_outreach_snapshots_day` (`organization_id`,`scope_key`,`snapshot_on`),
  KEY `fk_outreach_snapshots_sequences_tenant` (`organization_id`,`sequence_id`),
  CONSTRAINT `fk_outreach_snapshots_organizations` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_outreach_snapshots_sequences_tenant` FOREIGN KEY (`organization_id`, `sequence_id`) REFERENCES `sequences` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `people`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `people` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `display_name` varchar(255) NOT NULL,
  `version` int NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `lifecycle_stage` varchar(255) NOT NULL DEFAULT 'prospect',
  `visibility` varchar(255) NOT NULL DEFAULT 'public',
  `primary_email` varchar(255) DEFAULT NULL,
  `primary_phone` varchar(255) DEFAULT NULL,
  `merged_into_id` varchar(36) DEFAULT NULL,
  `erased_at` datetime(6) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `region` varchar(255) DEFAULT NULL,
  `do_not_contact` tinyint(1) NOT NULL DEFAULT '0',
  `source_system` varchar(255) DEFAULT NULL,
  `source_id` varchar(255) DEFAULT NULL,
  `do_not_contact_reason` varchar(255) DEFAULT NULL,
  `owner_user_id` varchar(36) DEFAULT NULL,
  `headline` varchar(255) DEFAULT NULL,
  `current_title` varchar(255) DEFAULT NULL,
  `current_company_id` varchar(36) DEFAULT NULL,
  `city` varchar(255) DEFAULT NULL,
  `time_zone` varchar(255) DEFAULT NULL,
  `source` varchar(255) DEFAULT NULL,
  `source_detail` varchar(255) DEFAULT NULL,
  `sourced_by_user_id` varchar(36) DEFAULT NULL,
  `sourced_at` datetime(6) DEFAULT NULL,
  `last_contacted_at` datetime(6) DEFAULT NULL,
  `last_replied_at` datetime(6) DEFAULT NULL,
  `last_activity_at` datetime(6) DEFAULT NULL,
  `engagement_status` varchar(255) NOT NULL DEFAULT 'not_contacted',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_people_tenant_pk` (`organization_id`,`id`),
  KEY `index_people_on_organization_id_and_lifecycle_stage` (`organization_id`,`lifecycle_stage`),
  KEY `index_people_on_organization_id_and_primary_email` (`organization_id`,`primary_email`),
  KEY `index_people_source` (`organization_id`,`source_system`,`source_id`),
  KEY `index_people_owner` (`organization_id`,`owner_user_id`),
  KEY `index_people_display_name` (`organization_id`,`display_name`),
  KEY `index_people_engagement` (`organization_id`,`engagement_status`),
  KEY `index_people_source_kind` (`organization_id`,`source`),
  KEY `index_people_last_contacted` (`organization_id`,`last_contacted_at`),
  KEY `fk_people_current_company_tenant` (`organization_id`,`current_company_id`),
  CONSTRAINT `fk_people_current_company_tenant` FOREIGN KEY (`organization_id`, `current_company_id`) REFERENCES `companies` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_cc3c1c1fca` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `person_affiliations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `person_affiliations` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `company_id` varchar(36) NOT NULL,
  `title` varchar(255) DEFAULT NULL,
  `current` tinyint(1) NOT NULL DEFAULT '0',
  `started_on` date DEFAULT NULL,
  `ended_on` date DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_affiliations_tenant_pk` (`organization_id`,`id`),
  KEY `index_affiliations_person_company` (`organization_id`,`person_id`,`company_id`),
  KEY `fk_affiliations_companies_tenant` (`organization_id`,`company_id`),
  CONSTRAINT `fk_affiliations_companies_tenant` FOREIGN KEY (`organization_id`, `company_id`) REFERENCES `companies` (`organization_id`, `id`),
  CONSTRAINT `fk_affiliations_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_167e06c779` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `person_contact_points`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `person_contact_points` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `kind` varchar(255) NOT NULL,
  `value` varchar(255) NOT NULL,
  `normalized_value` varchar(255) NOT NULL,
  `verified` tinyint(1) NOT NULL DEFAULT '0',
  `primary` tinyint(1) NOT NULL DEFAULT '0',
  `duplicate_of_person_id` varchar(36) DEFAULT NULL,
  `canonical_key` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_contact_points_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_contact_points_unique_value` (`organization_id`,`kind`,`canonical_key`),
  KEY `index_person_contact_points_on_organization_id_and_person_id` (`organization_id`,`person_id`),
  CONSTRAINT `fk_contact_points_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_72b7a2a64e` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `person_notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `person_notes` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `author_user_id` varchar(36) DEFAULT NULL,
  `agent_id` varchar(36) DEFAULT NULL,
  `body` text NOT NULL,
  `pinned` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_person_notes_tenant_pk` (`organization_id`,`id`),
  KEY `index_person_notes_feed` (`organization_id`,`person_id`,`pinned`,`created_at`),
  CONSTRAINT `fk_person_notes_organizations` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_person_notes_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `person_tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `person_tags` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `tag_id` varchar(36) NOT NULL,
  `added_by_user_id` varchar(36) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_person_tags_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_person_tags_pair` (`organization_id`,`person_id`,`tag_id`),
  KEY `index_person_tags_tag` (`organization_id`,`tag_id`),
  CONSTRAINT `fk_person_tags_organizations` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_person_tags_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `fk_person_tags_tags_tenant` FOREIGN KEY (`organization_id`, `tag_id`) REFERENCES `tags` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `pipeline_template_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pipeline_template_versions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `pipeline_template_id` varchar(36) NOT NULL,
  `version` int NOT NULL,
  `stages` json NOT NULL,
  `published_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_pipeline_template_versions_unique` (`organization_id`,`pipeline_template_id`,`version`),
  UNIQUE KEY `index_pipeline_template_versions_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_549ff389f4` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_a4bae8006ac98094` FOREIGN KEY (`organization_id`, `pipeline_template_id`) REFERENCES `pipeline_templates` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `pipeline_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pipeline_templates` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `object_type` varchar(255) NOT NULL DEFAULT 'job',
  `published_version` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_pipeline_templates_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_pipeline_templates_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_e1a782ddd8` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `pipelines`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pipelines` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `scope` varchar(255) NOT NULL,
  `pipeline_template_id` varchar(36) DEFAULT NULL,
  `template_version` int NOT NULL DEFAULT '0',
  `overrides` json NOT NULL,
  `version` int NOT NULL DEFAULT '1',
  `needs_review` tinyint(1) NOT NULL DEFAULT '0',
  `resolved_stages` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_pipelines_tenant_pk` (`organization_id`,`id`),
  KEY `tenant_fk_d74ca9df7e868555` (`organization_id`,`pipeline_template_id`),
  CONSTRAINT `fk_rails_bdf19edfed` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_d74ca9df7e868555` FOREIGN KEY (`organization_id`, `pipeline_template_id`) REFERENCES `pipeline_templates` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `postings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `postings` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `job_id` varchar(36) NOT NULL,
  `title` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'draft',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `audience` varchar(255) NOT NULL,
  `questions` json DEFAULT NULL,
  `template_questions` json DEFAULT NULL,
  `question_template_id` varchar(36) DEFAULT NULL,
  `template_version` int DEFAULT NULL,
  `version` int NOT NULL DEFAULT '1',
  `description` text,
  `location` varchar(255) DEFAULT NULL,
  `employment_type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_postings_tenant_pk` (`organization_id`,`id`),
  KEY `fk_postings_jobs_tenant` (`organization_id`,`job_id`),
  KEY `fk_postings_question_template` (`organization_id`,`question_template_id`),
  CONSTRAINT `fk_postings_jobs_tenant` FOREIGN KEY (`organization_id`, `job_id`) REFERENCES `jobs` (`organization_id`, `id`),
  CONSTRAINT `fk_postings_question_template` FOREIGN KEY (`organization_id`, `question_template_id`) REFERENCES `application_question_templates` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_48f63fd2f7` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `project_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_members` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `project_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `pipeline_id` varchar(36) DEFAULT NULL,
  `pipeline_version` int DEFAULT NULL,
  `current_stage_key` varchar(255) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `converted_application_id` varchar(36) DEFAULT NULL,
  `version` int NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `note` text,
  `added_by_user_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_project_members_unique` (`organization_id`,`project_id`,`person_id`),
  UNIQUE KEY `index_project_members_tenant_pk` (`organization_id`,`id`),
  KEY `fk_project_members_people_tenant` (`organization_id`,`person_id`),
  KEY `tenant_fk_44362b1a3140f873` (`organization_id`,`pipeline_id`),
  CONSTRAINT `fk_project_members_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `fk_project_members_projects_tenant` FOREIGN KEY (`organization_id`, `project_id`) REFERENCES `projects` (`organization_id`, `id`),
  CONSTRAINT `fk_rails_7d23213ba6` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_44362b1a3140f873` FOREIGN KEY (`organization_id`, `pipeline_id`) REFERENCES `pipelines` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `projects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `projects` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `pipeline_id` varchar(36) DEFAULT NULL,
  `job_id` varchar(36) DEFAULT NULL,
  `confidential` tinyint(1) NOT NULL DEFAULT '0',
  `version` int NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `description` text,
  `owner_user_id` varchar(36) DEFAULT NULL,
  `saved_search_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_projects_tenant_pk` (`organization_id`,`id`),
  KEY `tenant_fk_e8181113e21ccddb` (`organization_id`,`job_id`),
  KEY `tenant_fk_ceab5f32c98b482e` (`organization_id`,`pipeline_id`),
  CONSTRAINT `fk_rails_9aee26923d` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_ceab5f32c98b482e` FOREIGN KEY (`organization_id`, `pipeline_id`) REFERENCES `pipelines` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_e8181113e21ccddb` FOREIGN KEY (`organization_id`, `job_id`) REFERENCES `jobs` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `rediscovery_candidates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `rediscovery_candidates` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `job_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'pending',
  `bucket` varchar(255) NOT NULL,
  `score` int NOT NULL DEFAULT '0',
  `verdicts` json NOT NULL,
  `reasons` json NOT NULL,
  `feedback` text,
  `reviewed_by_user_id` varchar(36) DEFAULT NULL,
  `reviewed_at` datetime(6) DEFAULT NULL,
  `found_by_agent_id` varchar(36) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_rediscovery_candidates_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_rediscovery_candidates_pair` (`organization_id`,`job_id`,`person_id`),
  KEY `index_rediscovery_candidates_queue` (`organization_id`,`job_id`,`status`,`score`),
  KEY `fk_rediscovery_candidates_people_tenant` (`organization_id`,`person_id`),
  CONSTRAINT `fk_rediscovery_candidates_jobs_tenant` FOREIGN KEY (`organization_id`, `job_id`) REFERENCES `jobs` (`organization_id`, `id`),
  CONSTRAINT `fk_rediscovery_candidates_organizations` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_rediscovery_candidates_people_tenant` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `referrals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `referrals` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `referrer_user_id` varchar(36) NOT NULL,
  `job_id` varchar(36) DEFAULT NULL,
  `application_id` varchar(36) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'submitted',
  `note` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_referrals_tenant_pk` (`organization_id`,`id`),
  KEY `index_referrals_on_organization_id_and_person_id` (`organization_id`,`person_id`),
  KEY `index_referrals_on_organization_id_and_referrer_user_id` (`organization_id`,`referrer_user_id`),
  KEY `index_referrals_on_organization_id_and_job_id` (`organization_id`,`job_id`),
  KEY `tenant_fk_d5cbaed53615f75c` (`organization_id`,`application_id`),
  CONSTRAINT `fk_rails_287749c24a` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_0557f96c036961e9` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_d5cbaed53615f75c` FOREIGN KEY (`organization_id`, `application_id`) REFERENCES `applications` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_ebdfb4d7c7f81b2d` FOREIGN KEY (`organization_id`, `job_id`) REFERENCES `jobs` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `requisitions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `requisitions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `code` varchar(255) NOT NULL,
  `title` varchar(255) NOT NULL,
  `employment_type` varchar(255) DEFAULT NULL,
  `headcount` int NOT NULL DEFAULT '1',
  `status` varchar(255) NOT NULL DEFAULT 'draft',
  `owner_user_id` varchar(36) DEFAULT NULL,
  `approved_at` datetime(6) DEFAULT NULL,
  `closed_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_requisitions_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_requisitions_on_organization_id_and_code` (`organization_id`,`code`),
  KEY `index_requisitions_on_organization_id_and_status` (`organization_id`,`status`),
  CONSTRAINT `fk_rails_9401bb914a` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `retention_actions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `retention_actions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `action` varchar(255) NOT NULL,
  `compliance_policy_id` varchar(36) DEFAULT NULL,
  `actor_id` varchar(36) DEFAULT NULL,
  `details` json DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_retention_actions_tenant_pk` (`organization_id`,`id`),
  KEY `index_retention_actions_person` (`organization_id`,`person_id`,`created_at`),
  CONSTRAINT `fk_rails_e8fd2b81e5` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_9fda48175ceb932c` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `role_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `role_permissions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `role_id` varchar(36) NOT NULL,
  `permission` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_role_permissions_unique` (`organization_id`,`role_id`,`permission`),
  UNIQUE KEY `index_role_permissions_tenant_pk` (`organization_id`,`id`),
  KEY `fk_rails_60126080bd` (`role_id`),
  CONSTRAINT `fk_rails_19a87579e0` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_rails_60126080bd` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`),
  CONSTRAINT `tenant_fk_0f39968e02857727` FOREIGN KEY (`organization_id`, `role_id`) REFERENCES `roles` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `system` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_roles_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_roles_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_2f99738edd` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `rooms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `rooms` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `resource_email` varchar(255) NOT NULL,
  `location_key` varchar(255) DEFAULT NULL,
  `capacity` int NOT NULL DEFAULT '4',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_rooms_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_rooms_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_c2da7dc036` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sandbox_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sandbox_messages` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `mailbox_id` varchar(36) NOT NULL,
  `direction` varchar(255) NOT NULL,
  `rfc822_message_id` varchar(255) NOT NULL,
  `in_reply_to` varchar(255) DEFAULT NULL,
  `thread_id` varchar(255) NOT NULL,
  `from_address` varchar(255) NOT NULL,
  `to_address` varchar(255) NOT NULL,
  `subject` varchar(255) DEFAULT NULL,
  `mime` mediumtext,
  `delivered_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_sandbox_messages_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_sandbox_messages_rfc822` (`organization_id`,`rfc822_message_id`),
  KEY `index_sandbox_messages_mailbox` (`organization_id`,`mailbox_id`,`created_at`),
  KEY `index_sandbox_messages_thread` (`organization_id`,`thread_id`),
  CONSTRAINT `fk_rails_30451745e9` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_sandbox_messages_mailboxes_tenant` FOREIGN KEY (`organization_id`, `mailbox_id`) REFERENCES `mailboxes` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `saved_searches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `saved_searches` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `entity_type` varchar(255) NOT NULL DEFAULT 'person',
  `filters` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_saved_searches_tenant_pk` (`organization_id`,`id`),
  KEY `index_saved_searches_on_organization_id_and_user_id` (`organization_id`,`user_id`),
  CONSTRAINT `fk_rails_55a7f27984` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `scheduled_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scheduled_messages` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `mailbox_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `sequence_enrollment_id` varchar(36) DEFAULT NULL,
  `template_key` varchar(255) DEFAULT NULL,
  `subject` varchar(255) NOT NULL,
  `body` text NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'queued',
  `send_at` datetime(6) NOT NULL,
  `attempts` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `rfc822_message_id` varchar(255) DEFAULT NULL,
  `message_type` varchar(255) DEFAULT NULL,
  `defer_reason` varchar(255) DEFAULT NULL,
  `last_error` varchar(255) DEFAULT NULL,
  `communication_id` varchar(36) DEFAULT NULL,
  `sent_at` datetime(6) DEFAULT NULL,
  `sequence_step_id` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_scheduled_messages_tenant_pk` (`organization_id`,`id`),
  KEY `index_scheduled_messages_queue` (`organization_id`,`status`,`send_at`),
  KEY `index_scheduled_messages_step` (`organization_id`,`sequence_enrollment_id`,`sequence_step_id`),
  KEY `tenant_fk_6ae7207793d2b381` (`organization_id`,`mailbox_id`),
  KEY `tenant_fk_6524e2da20eaeae1` (`organization_id`,`person_id`),
  CONSTRAINT `fk_rails_1e122cb12e` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_6524e2da20eaeae1` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_6ae7207793d2b381` FOREIGN KEY (`organization_id`, `mailbox_id`) REFERENCES `mailboxes` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `scheduling_links`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scheduling_links` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `application_id` varchar(36) NOT NULL,
  `kind` varchar(255) NOT NULL,
  `interview_keys` json NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `used_at` datetime(6) DEFAULT NULL,
  `revoked_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_scheduling_links_tenant_pk` (`organization_id`,`id`),
  KEY `index_scheduling_links_on_organization_id_and_application_id` (`organization_id`,`application_id`),
  CONSTRAINT `fk_rails_a48596018f` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_scheduling_links_applications_tenant` FOREIGN KEY (`organization_id`, `application_id`) REFERENCES `applications` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `scorecard_rubrics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scorecard_rubrics` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `guidance` text,
  `attributes_spec` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_scorecard_rubrics_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_scorecard_rubrics_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_e75981f13d` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `scorecards`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scorecards` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `interview_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'draft',
  `rating` varchar(255) DEFAULT NULL,
  `notes` text,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `attribute_ratings` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_on_organization_id_interview_id_user_id_a93887f0c2` (`organization_id`,`interview_id`,`user_id`),
  UNIQUE KEY `index_scorecards_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_59bd91c764` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_6076e9f551e8b67a` FOREIGN KEY (`organization_id`, `interview_id`) REFERENCES `interviews` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sequence_enrollments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sequence_enrollments` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `sequence_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `mailbox_id` varchar(36) NOT NULL,
  `step_index` int NOT NULL DEFAULT '0',
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `stop_reason` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `next_run_at` datetime(6) DEFAULT NULL,
  `merge_fields` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_enrollments_unique` (`organization_id`,`sequence_id`,`person_id`),
  UNIQUE KEY `index_enrollments_tenant_pk` (`organization_id`,`id`),
  KEY `index_sequence_enrollments_due` (`status`,`next_run_at`),
  KEY `tenant_fk_71b620f2d9008f4a` (`organization_id`,`mailbox_id`),
  KEY `tenant_fk_643adbe64872cd24` (`organization_id`,`person_id`),
  CONSTRAINT `fk_rails_9d9bc00bf7` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_643adbe64872cd24` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_71b620f2d9008f4a` FOREIGN KEY (`organization_id`, `mailbox_id`) REFERENCES `mailboxes` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_b329a7acc09c76ed` FOREIGN KEY (`organization_id`, `sequence_id`) REFERENCES `sequences` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sequences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sequences` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `steps` json NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `shared` tinyint(1) NOT NULL DEFAULT '1',
  `is_template` tinyint(1) NOT NULL DEFAULT '0',
  `description` text,
  `owner_user_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_sequences_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_sequences_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_932ca41d34` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `signature_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `signature_requests` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `offer_version_id` varchar(36) NOT NULL,
  `provider` varchar(255) NOT NULL DEFAULT 'click_to_accept',
  `sent_to_email` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'sent',
  `expires_at` datetime(6) NOT NULL,
  `viewed_at` datetime(6) DEFAULT NULL,
  `completed_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_signature_requests_tenant_pk` (`organization_id`,`id`),
  KEY `idx_on_organization_id_offer_version_id_b1bbebc145` (`organization_id`,`offer_version_id`),
  CONSTRAINT `fk_rails_d51d1b6149` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_5f5da0088f241d9e` FOREIGN KEY (`organization_id`, `offer_version_id`) REFERENCES `offer_versions` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `solid_cache_entries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `solid_cache_entries` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `key` varbinary(1024) NOT NULL,
  `value` longblob NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `key_hash` bigint NOT NULL,
  `byte_size` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_solid_cache_entries_on_key_hash` (`key_hash`),
  KEY `index_solid_cache_entries_on_byte_size` (`byte_size`),
  KEY `index_solid_cache_entries_on_key_hash_and_byte_size` (`key_hash`,`byte_size`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sourcing_tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sourcing_tasks` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `sequence_enrollment_id` varchar(36) DEFAULT NULL,
  `assignee_user_id` varchar(36) DEFAULT NULL,
  `title` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'open',
  `due_at` datetime(6) DEFAULT NULL,
  `completed_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `task_type` varchar(255) NOT NULL DEFAULT 'other',
  `description` text,
  `assignee_agent_id` varchar(36) DEFAULT NULL,
  `application_id` varchar(36) DEFAULT NULL,
  `project_member_id` varchar(36) DEFAULT NULL,
  `created_by_user_id` varchar(36) DEFAULT NULL,
  `pauses_enrollment` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_sourcing_tasks_tenant_pk` (`organization_id`,`id`),
  KEY `index_sourcing_tasks_on_organization_id_and_status` (`organization_id`,`status`),
  KEY `index_sourcing_tasks_on_organization_id_and_person_id` (`organization_id`,`person_id`),
  KEY `index_sourcing_tasks_queue` (`organization_id`,`assignee_user_id`,`status`,`due_at`),
  KEY `tenant_fk_9c685702f8273d92` (`organization_id`,`sequence_enrollment_id`),
  KEY `fk_sourcing_tasks_applications_tenant` (`organization_id`,`application_id`),
  KEY `fk_sourcing_tasks_project_members_tenant` (`organization_id`,`project_member_id`),
  CONSTRAINT `fk_rails_118f12b0a6` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `fk_sourcing_tasks_applications_tenant` FOREIGN KEY (`organization_id`, `application_id`) REFERENCES `applications` (`organization_id`, `id`),
  CONSTRAINT `fk_sourcing_tasks_project_members_tenant` FOREIGN KEY (`organization_id`, `project_member_id`) REFERENCES `project_members` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_9c685702f8273d92` FOREIGN KEY (`organization_id`, `sequence_enrollment_id`) REFERENCES `sequence_enrollments` (`organization_id`, `id`),
  CONSTRAINT `tenant_fk_a76b11f821511d1c` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `stage_transitions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stage_transitions` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `subject_type` varchar(255) NOT NULL,
  `subject_id` varchar(36) NOT NULL,
  `from_stage_key` varchar(255) DEFAULT NULL,
  `to_stage_key` varchar(255) NOT NULL,
  `command` varchar(255) NOT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `actor_id` varchar(36) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_stage_transitions_tenant_pk` (`organization_id`,`id`),
  KEY `index_stage_transitions_subject` (`organization_id`,`subject_type`,`subject_id`),
  CONSTRAINT `fk_rails_8a49caca85` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `normalized_name` varchar(255) NOT NULL,
  `color` varchar(255) NOT NULL DEFAULT '#64748b',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_tags_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_tags_name` (`organization_id`,`normalized_name`),
  CONSTRAINT `fk_tags_organizations` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `timeline_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `timeline_events` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `person_id` varchar(36) NOT NULL,
  `event_type` varchar(255) NOT NULL,
  `outbox_event_id` varchar(36) DEFAULT NULL,
  `payload` json NOT NULL,
  `occurred_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_timeline_events_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_timeline_events_outbox` (`organization_id`,`outbox_event_id`),
  KEY `index_timeline_events_person` (`organization_id`,`person_id`,`occurred_at`),
  CONSTRAINT `fk_rails_f691d8dc1f` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_0380f5df748bb934` FOREIGN KEY (`organization_id`, `person_id`) REFERENCES `people` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` varchar(36) NOT NULL,
  `email` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_users_on_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `verified_domains`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `verified_domains` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `domain` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'pending',
  `verified_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_verified_domains_on_organization_id_and_domain` (`organization_id`,`domain`),
  UNIQUE KEY `index_verified_domains_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_e536789e46` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `webhook_deliveries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `webhook_deliveries` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `webhook_endpoint_id` varchar(36) NOT NULL,
  `outbox_event_id` varchar(36) NOT NULL,
  `event_type` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'pending',
  `attempt_count` int NOT NULL DEFAULT '0',
  `response_status` int DEFAULT NULL,
  `response_snippet` varchar(255) DEFAULT NULL,
  `delivered_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `next_attempt_at` datetime(6) DEFAULT NULL,
  `last_error` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_webhook_deliveries_tenant_pk` (`organization_id`,`id`),
  UNIQUE KEY `index_webhook_deliveries_once` (`organization_id`,`webhook_endpoint_id`,`outbox_event_id`),
  KEY `index_webhook_deliveries_status` (`organization_id`,`webhook_endpoint_id`,`status`),
  KEY `index_webhook_deliveries_due` (`status`,`next_attempt_at`),
  CONSTRAINT `fk_rails_ea5a0897ac` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  CONSTRAINT `tenant_fk_e9090de3057319aa` FOREIGN KEY (`organization_id`, `webhook_endpoint_id`) REFERENCES `webhook_endpoints` (`organization_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `webhook_endpoints`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `webhook_endpoints` (
  `id` varchar(36) NOT NULL,
  `organization_id` varchar(36) NOT NULL,
  `key` varchar(255) NOT NULL,
  `url` varchar(255) NOT NULL,
  `secret_ref` varchar(255) NOT NULL,
  `event_types` json DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_webhook_endpoints_on_organization_id_and_key` (`organization_id`,`key`),
  UNIQUE KEY `index_webhook_endpoints_tenant_pk` (`organization_id`,`id`),
  CONSTRAINT `fk_rails_21808fa528` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50112 SET @disable_bulk_load = IF (@is_rocksdb_supported, 'SET SESSION rocksdb_bulk_load = @old_rocksdb_bulk_load', 'SET @dummy_rocksdb_bulk_load = 0') */;
/*!50112 PREPARE s FROM @disable_bulk_load */;
/*!50112 EXECUTE s */;
/*!50112 DEALLOCATE PREPARE s */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

INSERT INTO `schema_migrations` (version) VALUES
('20261111030000'),
('20261109100000'),
('20261108280000'),
('20261108270000'),
('20261108260000'),
('20261108250000'),
('20261108240000'),
('20261108230000'),
('20261108220000'),
('20261108210000'),
('20261108200000'),
('20261108190000'),
('20261107160000'),
('20261107150000'),
('20261105140000'),
('20261105133000'),
('20261105132000'),
('20261105131000'),
('20261105130000'),
('20261105120000'),
('20261105010000'),
('20261104200000'),
('20261104190000'),
('20261104120000'),
('20261104010000'),
('20261103130000'),
('20261103120000'),
('20261103110000'),
('20261103100000'),
('20261025240000'),
('20261025230000'),
('20261025220000'),
('20261025210000'),
('20261025200000'),
('20261025192000'),
('20261025191000'),
('20261025190000'),
('20261025180000'),
('20261025170000'),
('20261025160000'),
('20261025150000'),
('20261025140000');

