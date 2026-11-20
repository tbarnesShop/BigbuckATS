# Big Buck MCP tools

Generated from `openapi/openapi.yaml` (228 operations).

Write tools require `BIGBUCK_MCP_ALLOW_WRITES=true`.

| Tool | Method | Path | Write |
|---|---|---|---|
| `acceptPublicOffer` | POST | `/public/offers/{token}/accept` | yes |
| `addHiringTeamMember` | POST | `/jobs/{id}/hiring_team/members` | yes |
| `addJobApplicantsToProject` | POST | `/projects/{id}/from_job` | yes |
| `addPeopleToProject` | POST | `/projects/{id}/people` | yes |
| `addProjectMember` | POST | `/projects/{id}/members` | yes |
| `applyConfigPlan` | POST | `/config/apply` | yes |
| `approveAgentProposal` | POST | `/agent_proposals/{id}/approve` | yes |
| `approveOffer` | POST | `/offers/{id}/approve` | yes |
| `archiveCustomField` | POST | `/custom_fields/{id}/archive` | yes |
| `archiveMessageTemplate` | POST | `/message_templates/{id}/archive` | yes |
| `bookPanel` | POST | `/applications/{id}/bookings` | yes |
| `bookPublicSlot` | POST | `/public/scheduling/{token}/book` | yes |
| `bulkApproveAgentProposals` | POST | `/agent_proposals/bulk_approve` | yes |
| `bulkEnrollSequence` | POST | `/sequences/{id}/bulk_enroll` | yes |
| `bulkMoveProjectMembers` | POST | `/projects/{id}/transitions` | yes |
| `bulkPeopleAction` | POST | `/people/bulk` | yes |
| `cancelInterview` | POST | `/interviews/{id}/cancel` | yes |
| `cancelTask` | POST | `/tasks/{id}/cancel` | yes |
| `changeCustomFieldType` | POST | `/custom_fields/{id}/type_change` | yes |
| `classifyCommunication` | PATCH | `/communications/{id}` | yes |
| `closeRequisition` | POST | `/requisitions/{id}/close` | yes |
| `completeDataRequest` | POST | `/data_requests/{id}/complete` | yes |
| `completeSourcingTask` | POST | `/sourcing_tasks/{id}/complete` | yes |
| `completeTask` | POST | `/tasks/{id}/complete` | yes |
| `confirmPublicUnsubscribe` | POST | `/public/unsubscribe/{token}` | yes |
| `convertProjectMember` | POST | `/project_members/{id}/convert` | yes |
| `createAffiliation` | POST | `/affiliations` | yes |
| `createAgent` | POST | `/agents` | yes |
| `createAgentCredential` | POST | `/agents/{id}/credentials` | yes |
| `createApplication` | POST | `/applications` | yes |
| `createApplicationOffer` | POST | `/applications/{id}/offers` | yes |
| `createApplicationQuestionTemplate` | POST | `/application_question_templates` | yes |
| `createApplicationTransition` | POST | `/applications/{id}/transitions` | yes |
| `createCalendarConnection` | POST | `/calendar_connections` | yes |
| `createCompany` | POST | `/companies` | yes |
| `createConfigPlan` | POST | `/config/plans` | yes |
| `createCredential` | POST | `/credentials` | yes |
| `createCustomField` | POST | `/custom_fields` | yes |
| `createDataRequest` | POST | `/data_requests` | yes |
| `createDncCompany` | POST | `/dnc_companies` | yes |
| `createImport` | POST | `/imports` | yes |
| `createJob` | POST | `/jobs` | yes |
| `createJobPosting` | POST | `/jobs/{job_id}/postings` | yes |
| `createLegalHold` | POST | `/legal_holds` | yes |
| `createMailbox` | POST | `/mailboxes` | yes |
| `createMessageTemplate` | POST | `/message_templates` | yes |
| `createOauthIdentity` | POST | `/oauth_identities` | yes |
| `createOrganization` | POST | `/organizations` | yes |
| `createPerson` | POST | `/people` | yes |
| `createPersonNote` | POST | `/people/{person_id}/notes` | yes |
| `createProject` | POST | `/projects` | yes |
| `createReferral` | POST | `/referrals` | yes |
| `createRequisition` | POST | `/requisitions` | yes |
| `createSavedSearch` | POST | `/saved_searches` | yes |
| `createSchedulingLink` | POST | `/applications/{id}/scheduling_links` | yes |
| `createScorecard` | POST | `/scorecards` | yes |
| `createScorecardRubric` | POST | `/scorecard_rubrics` | yes |
| `createSequence` | POST | `/sequences` | yes |
| `createSession` | POST | `/sessions` | yes |
| `createTag` | POST | `/tags` | yes |
| `createTask` | POST | `/tasks` | yes |
| `createWebhook` | POST | `/webhooks` | yes |
| `declinePublicOffer` | POST | `/public/offers/{token}/decline` | yes |
| `deleteCurrentSession` | DELETE | `/sessions/current` | yes |
| `deleteDncCompany` | DELETE | `/dnc_companies/{id}` | yes |
| `deletePersonNote` | DELETE | `/notes/{id}` | yes |
| `deleteSavedSearch` | DELETE | `/saved_searches/{id}` | yes |
| `drainWebhooks` | POST | `/webhooks/drain` | yes |
| `enrollInSequence` | POST | `/sequences/{id}/enrollments` | yes |
| `enrollPlannedPeople` | POST | `/sequences/{id}/enroll_planned` | yes |
| `erasePerson` | POST | `/people/{id}/erase` | yes |
| `exchangeSessionCode` | POST | `/sessions/exchange` | yes |
| `finishGoogleSignIn` | GET | `/oauth/google/callback` |  |
| `getAccessPacket` | GET | `/people/{id}/access_packet` |  |
| `getAgent` | GET | `/agents/{id}` |  |
| `getApplication` | GET | `/applications/{id}` |  |
| `getApplicationForm` | GET | `/application_form` |  |
| `getApplicationMissingFeedback` | GET | `/applications/{id}/missing_feedback` |  |
| `getCompany` | GET | `/companies/{id}` |  |
| `getCompliancePolicy` | GET | `/compliance_policies/{id}` |  |
| `getCurrentSession` | GET | `/sessions/current` |  |
| `getCustomField` | GET | `/custom_fields/{id}` |  |
| `getEnrollment` | GET | `/enrollments/{id}` |  |
| `getFunnelAnalytics` | GET | `/analytics/funnel` |  |
| `getGoogleSignInStatus` | GET | `/oauth/google/status` |  |
| `getHealth` | GET | `/health` |  |
| `getImport` | GET | `/imports/{id}` |  |
| `getInternalCareers` | GET | `/internal/careers` |  |
| `getInterview` | GET | `/interviews/{id}` |  |
| `getJob` | GET | `/jobs/{id}` |  |
| `getOffer` | GET | `/offers/{id}` |  |
| `getOutreachFunnel` | GET | `/analytics/outreach` |  |
| `getPerson` | GET | `/people/{id}` |  |
| `getPersonDocument` | GET | `/people/{person_id}/documents/{id}` |  |
| `getPersonFeed` | GET | `/people/{id}/feed` |  |
| `getPersonTimeline` | GET | `/people/{id}/timeline` |  |
| `getProject` | GET | `/projects/{id}` |  |
| `getProjectMember` | GET | `/project_members/{id}` |  |
| `getPublicCareers` | GET | `/public/careers/{slug}` |  |
| `getPublicOffer` | GET | `/public/offers/{token}` |  |
| `getPublicScheduling` | GET | `/public/scheduling/{token}` |  |
| `getPublicUnsubscribe` | GET | `/public/unsubscribe/{token}` |  |
| `getRediscoveryCriteria` | GET | `/jobs/{job_id}/rediscovery/criteria` |  |
| `getReferral` | GET | `/referrals/{id}` |  |
| `getRequisition` | GET | `/requisitions/{id}` |  |
| `getSequence` | GET | `/sequences/{id}` |  |
| `getSequenceStats` | GET | `/sequences/{id}/stats` |  |
| `getSourcingAnalytics` | GET | `/analytics/sourcing` |  |
| `getToday` | GET | `/today` |  |
| `ingestInboundMessage` | POST | `/mailboxes/{id}/inbound` | yes |
| `jobFormOptions` | GET | `/jobs/form_options` |  |
| `listAffiliations` | GET | `/affiliations` |  |
| `listAgentProposals` | GET | `/agent_proposals` |  |
| `listAgents` | GET | `/agents` |  |
| `listAllProjectMembers` | GET | `/project_members` |  |
| `listApplicationInterviews` | GET | `/applications/{id}/interviews` |  |
| `listApplicationQuestionTemplates` | GET | `/application_question_templates` |  |
| `listApplications` | GET | `/applications` |  |
| `listApplicationTransitions` | GET | `/applications/{id}/transitions` |  |
| `listAwaitingSchedule` | GET | `/interviews/awaiting_schedule` |  |
| `listCalendarConnections` | GET | `/calendar_connections` |  |
| `listCompanies` | GET | `/companies` |  |
| `listCompliancePolicies` | GET | `/compliance_policies` |  |
| `listConfigPlans` | GET | `/config/plans` |  |
| `listCredentials` | GET | `/credentials` |  |
| `listCustomFields` | GET | `/custom_fields` |  |
| `listDataRequests` | GET | `/data_requests` |  |
| `listDemoMemberships` | GET | `/sessions/demo_memberships` |  |
| `listDncCompanies` | GET | `/dnc_companies` |  |
| `listEnrollments` | GET | `/enrollments` |  |
| `listEvents` | GET | `/events` |  |
| `listImports` | GET | `/imports` |  |
| `listInterviews` | GET | `/interviews` |  |
| `listJobPostings` | GET | `/jobs/{job_id}/postings` |  |
| `listJobs` | GET | `/jobs` |  |
| `listLegalHolds` | GET | `/legal_holds` |  |
| `listMailboxes` | GET | `/mailboxes` |  |
| `listMailboxMessages` | GET | `/mailboxes/{id}/messages` |  |
| `listMessageTemplates` | GET | `/message_templates` |  |
| `listOauthIdentities` | GET | `/oauth_identities` |  |
| `listOffers` | GET | `/offers` |  |
| `listOutreachSnapshots` | GET | `/analytics/outreach_snapshots` |  |
| `listPeople` | GET | `/people` |  |
| `listPersonCommunications` | GET | `/people/{id}/communications` |  |
| `listPersonConsents` | GET | `/people/{id}/consents` |  |
| `listPersonDocuments` | GET | `/people/{person_id}/documents` |  |
| `listPersonNotes` | GET | `/people/{person_id}/notes` |  |
| `listPersonTags` | GET | `/people/{person_id}/tags` |  |
| `listProjectMembers` | GET | `/projects/{id}/members` |  |
| `listProjectMemberTransitions` | GET | `/project_members/{id}/transitions` |  |
| `listProjects` | GET | `/projects` |  |
| `listRediscoveryQueue` | GET | `/jobs/{job_id}/rediscovery/queue` |  |
| `listReferrals` | GET | `/referrals` |  |
| `listRequisitions` | GET | `/requisitions` |  |
| `listSavedSearches` | GET | `/saved_searches` |  |
| `listScorecardRubrics` | GET | `/scorecard_rubrics` |  |
| `listScorecards` | GET | `/scorecards` |  |
| `listSequenceEnrollments` | GET | `/sequences/{id}/enrollments` |  |
| `listSequences` | GET | `/sequences` |  |
| `listSourcingTasks` | GET | `/sourcing_tasks` |  |
| `listTags` | GET | `/tags` |  |
| `listTasks` | GET | `/tasks` |  |
| `listTeam` | GET | `/team` |  |
| `listWebhooks` | GET | `/webhooks` |  |
| `mergeTag` | POST | `/tags/{id}/merge` | yes |
| `openRequisition` | POST | `/requisitions/{id}/open` | yes |
| `pauseAgent` | POST | `/agents/{id}/pause` | yes |
| `planSequenceEnrollment` | POST | `/sequences/{id}/enrollment_plan` | yes |
| `previewPanel` | POST | `/applications/{id}/booking_options` | yes |
| `previewPersonMessage` | POST | `/people/{id}/preview_message` | yes |
| `previewSequence` | GET | `/sequences/{id}/preview` |  |
| `recordOfferResponse` | POST | `/offers/{id}/record_response` | yes |
| `recordPersonConsent` | POST | `/people/{id}/consents` | yes |
| `rediscoverTalent` | GET | `/jobs/{id}/rediscovery` |  |
| `rejectAgentProposal` | POST | `/agent_proposals/{id}/reject` | yes |
| `rejectDataRequest` | POST | `/data_requests/{id}/reject` | yes |
| `releaseLegalHold` | POST | `/legal_holds/{id}/release` | yes |
| `removeHiringTeamMember` | POST | `/jobs/{id}/hiring_team/members/{member_id}/remove` | yes |
| `replacePersonResume` | POST | `/people/{person_id}/documents` | yes |
| `rescheduleInterview` | POST | `/interviews/{id}/reschedule` | yes |
| `rescindOffer` | POST | `/offers/{id}/rescind` | yes |
| `resendOffer` | POST | `/offers/{id}/resend` | yes |
| `restoreCustomField` | POST | `/custom_fields/{id}/restore` | yes |
| `resumeAgent` | POST | `/agents/{id}/resume` | yes |
| `reviewRediscoveryCandidate` | POST | `/rediscovery_candidates/{id}/review` | yes |
| `revokeAgent` | POST | `/agents/{id}/revoke` | yes |
| `revokeCredential` | POST | `/credentials/{id}/revoke` | yes |
| `revokeOauthIdentity` | POST | `/oauth_identities/{id}/revoke` | yes |
| `rotateWebhookSecret` | POST | `/webhooks/{id}/rotate_secret` | yes |
| `runRediscovery` | POST | `/jobs/{job_id}/rediscovery/run` | yes |
| `runSavedSearch` | GET | `/saved_searches/{id}/people` |  |
| `runSourcingAgent` | POST | `/jobs/{job_id}/sourcing_agent/run` | yes |
| `sendOffer` | POST | `/offers/{id}/send` | yes |
| `sendPersonCommunication` | POST | `/people/{id}/communications` | yes |
| `setCustomFieldValue` | PUT | `/custom_field_values` | yes |
| `setRediscoveryCriteria` | PUT | `/jobs/{job_id}/rediscovery/criteria` | yes |
| `simulateMailboxReply` | POST | `/mailboxes/{id}/simulate` | yes |
| `startGoogleSignIn` | GET | `/oauth/google` |  |
| `stopEnrollment` | POST | `/enrollments/{id}/stop` | yes |
| `submitInternalApplication` | POST | `/internal/careers/apply/{posting_id}` | yes |
| `submitOffer` | POST | `/offers/{id}/submit` | yes |
| `submitPublicApplication` | POST | `/public/careers/{slug}/apply/{posting_id}` | yes |
| `syncPeople` | GET | `/sync/people` |  |
| `tagPerson` | POST | `/people/{person_id}/tags` | yes |
| `transitionProjectMember` | POST | `/project_members/{id}/transitions` | yes |
| `untagPerson` | DELETE | `/people/{person_id}/tags/{id}` | yes |
| `updateApplicationForm` | PATCH | `/application_form` | yes |
| `updateApplicationQuestionTemplate` | PATCH | `/application_question_templates/{id}` | yes |
| `updateCustomField` | PATCH | `/custom_fields/{id}` | yes |
| `updateHiringTeamMember` | PATCH | `/jobs/{id}/hiring_team/members/{member_id}` | yes |
| `updateJob` | PATCH | `/jobs/{id}` | yes |
| `updateJobPipeline` | PATCH | `/jobs/{id}/pipeline` | yes |
| `updateJobPosting` | PATCH | `/postings/{id}` | yes |
| `updateMailbox` | PATCH | `/mailboxes/{id}` | yes |
| `updateMessageTemplate` | PATCH | `/message_templates/{id}` | yes |
| `updateOfferChecklist` | PATCH | `/offers/{id}/checklist` | yes |
| `updateOrganization` | PATCH | `/organizations/{id}` | yes |
| `updatePerson` | PATCH | `/people/{id}` | yes |
| `updatePersonNote` | PATCH | `/notes/{id}` | yes |
| `updateProject` | PATCH | `/projects/{id}` | yes |
| `updateProjectMember` | PATCH | `/project_members/{id}` | yes |
| `updateSavedSearch` | PATCH | `/saved_searches/{id}` | yes |
| `updateScorecard` | PATCH | `/scorecards/{id}` | yes |
| `updateScorecardRubric` | PATCH | `/scorecard_rubrics/{id}` | yes |
| `updateSequence` | PATCH | `/sequences/{id}` | yes |
| `updateTag` | PATCH | `/tags/{id}` | yes |
| `updateTask` | PATCH | `/tasks/{id}` | yes |
| `updateWebhook` | PATCH | `/webhooks/{id}` | yes |
