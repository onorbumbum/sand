# Final v1 Sandbox VM acceptance evidence

Date: 2026-05-19
Sandbox name: `sandv1accept519`
Host fixtures: `/tmp/sand-v1-acceptance-20260519`
Product CLI: `/Users/onorbumbum/_PROJECTS/sand/.build/debug/sand`


## Build product

```console
$ swift build
[0/1] Planning build
Building for debugging...
[0/3] Write swift-version--58304C5D6DBC2206.txt
Build complete! (0.11s)
[exit 0]
```

## swift test

```console
$ swift test
[0/1] Planning build
Building for debugging...
[0/4] Write swift-version--58304C5D6DBC2206.txt
Build complete! (0.11s)
Test Suite 'All tests' started at 2026-05-19 00:35:47.877.
Test Suite 'sandPackageTests.xctest' started at 2026-05-19 00:35:47.878.
Test Suite 'AppleContainerCLIBackendDoctorTests' started at 2026-05-19 00:35:47.878.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testApplyRecreatesStoppedRuntimeWithCurrentAllowedFoldersWhilePreservingGuestStateVolume]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testApplyRecreatesStoppedRuntimeWithCurrentAllowedFoldersWhilePreservingGuestStateVolume]' passed (0.001 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testApplyRestartsRuntimeAfterRecreatingIfItWasRunning]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testApplyRestartsRuntimeAfterRecreatingIfItWasRunning]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testDeleteUsesBackendForceAndDeletesGuestStateVolumeSoDestructiveConfirmationLivesOnlyInSand]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testDeleteUsesBackendForceAndDeletesGuestStateVolumeSoDestructiveConfirmationLivesOnlyInSand]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testDoctorReportsBackendServiceFailureWithoutMisreportingImageWhenAutoStartFails]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testDoctorReportsBackendServiceFailureWithoutMisreportingImageWhenAutoStartFails]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testDoctorReportsMissingDefaultSandboxImageAfterBackendServiceIsRunning]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testDoctorReportsMissingDefaultSandboxImageAfterBackendServiceIsRunning]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testMissingWorkloadCommandReturnsBackendExitCodeWithoutSwallowingContainerErrorOutput]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testMissingWorkloadCommandReturnsBackendExitCodeWithoutSwallowingContainerErrorOutput]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testProvisionCreatesNamedStoppedSandboxWithGuestStateVolumeAllowedFolderMountsResourceProfileAndImage]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testProvisionCreatesNamedStoppedSandboxWithGuestStateVolumeAllowedFolderMountsResourceProfileAndImage]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testProvisionThrowsWhenBackendCreateCommandFails]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testProvisionThrowsWhenBackendCreateCommandFails]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testProvisionWithoutAllowedFoldersDoesNotMountHostPiOrCredentialsByDefault]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testProvisionWithoutAllowedFoldersDoesNotMountHostPiOrCredentialsByDefault]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testRunAndShellPassSandboxUserAndWorkdirBeforeSandboxNameForAppleExecSyntaxAndUseInheritedTerminalIO]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testRunAndShellPassSandboxUserAndWorkdirBeforeSandboxNameForAppleExecSyntaxAndUseInheritedTerminalIO]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testRunDoesNotAllocateTTYForRedirectedUsageButKeepsStandardInputOpen]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testRunDoesNotAllocateTTYForRedirectedUsageButKeepsStandardInputOpen]' passed (0.000 seconds).
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testStatusTranslatesAppleInspectJsonToSandboxRuntimeStatus]' started.
Test Case '-[SandCoreTests.AppleContainerCLIBackendDoctorTests testStatusTranslatesAppleInspectJsonToSandboxRuntimeStatus]' passed (0.000 seconds).
Test Suite 'AppleContainerCLIBackendDoctorTests' passed at 2026-05-19 00:35:47.880.
	 Executed 12 tests, with 0 failures (0 unexpected) in 0.002 (0.002) seconds
Test Suite 'ArchitectureBoundaryTests' started at 2026-05-19 00:35:47.880.
Test Case '-[SandCoreTests.ArchitectureBoundaryTests testProductSourcesDoNotExposeFakeBackendsOrRawContainerOutsideAdapter]' started.
Test Case '-[SandCoreTests.ArchitectureBoundaryTests testProductSourcesDoNotExposeFakeBackendsOrRawContainerOutsideAdapter]' passed (0.006 seconds).
Test Suite 'ArchitectureBoundaryTests' passed at 2026-05-19 00:35:47.886.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.006 (0.006) seconds
Test Suite 'BackendErrorTranslationTests' started at 2026-05-19 00:35:47.886.
Test Case '-[SandCoreTests.BackendErrorTranslationTests testLogsTranslateRealAppleMissingRuntimeFixtureToUserFacingSandboxError]' started.
Test Case '-[SandCoreTests.BackendErrorTranslationTests testLogsTranslateRealAppleMissingRuntimeFixtureToUserFacingSandboxError]' passed (0.000 seconds).
Test Case '-[SandCoreTests.BackendErrorTranslationTests testStartReportsBackendServiceFailureInUserFacingLanguage]' started.
Test Case '-[SandCoreTests.BackendErrorTranslationTests testStartReportsBackendServiceFailureInUserFacingLanguage]' passed (0.000 seconds).
Test Suite 'BackendErrorTranslationTests' passed at 2026-05-19 00:35:47.886.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Suite 'CLICommandRouterTests' started at 2026-05-19 00:35:47.886.
Test Case '-[SandCoreTests.CLICommandRouterTests testAbsentV1CommandSurfaceIsRejected]' started.
Test Case '-[SandCoreTests.CLICommandRouterTests testAbsentV1CommandSurfaceIsRejected]' passed (0.000 seconds).
Test Case '-[SandCoreTests.CLICommandRouterTests testCommandResultCarriesProcessExitCode]' started.
Test Case '-[SandCoreTests.CLICommandRouterTests testCommandResultCarriesProcessExitCode]' passed (0.000 seconds).
Test Case '-[SandCoreTests.CLICommandRouterTests testCreateFromSpecRejectsExplicitNameThatDoesNotMatchSpecName]' started.
Test Case '-[SandCoreTests.CLICommandRouterTests testCreateFromSpecRejectsExplicitNameThatDoesNotMatchSpecName]' passed (0.000 seconds).
Test Case '-[SandCoreTests.CLICommandRouterTests testParsesEveryV1CommandShape]' started.
Test Case '-[SandCoreTests.CLICommandRouterTests testParsesEveryV1CommandShape]' passed (0.000 seconds).
Test Case '-[SandCoreTests.CLICommandRouterTests testRunCommandDispatchesOpaqueWorkloadThroughLifecycleBoundaryUnchangedAndDoesNotSpecialCasePi]' started.
Test Case '-[SandCoreTests.CLICommandRouterTests testRunCommandDispatchesOpaqueWorkloadThroughLifecycleBoundaryUnchangedAndDoesNotSpecialCasePi]' passed (0.000 seconds).
Test Suite 'CLICommandRouterTests' passed at 2026-05-19 00:35:47.887.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'DeveloperReadyImageDefinitionTests' started at 2026-05-19 00:35:47.887.
Test Case '-[SandCoreTests.DeveloperReadyImageDefinitionTests testDeveloperReadyImageBuildAndSmokeCommandsAreScripted]' started.
Test Case '-[SandCoreTests.DeveloperReadyImageDefinitionTests testDeveloperReadyImageBuildAndSmokeCommandsAreScripted]' passed (0.001 seconds).
Test Case '-[SandCoreTests.DeveloperReadyImageDefinitionTests testDeveloperReadyImageDefinitionDeclaresDefaultSandboxContract]' started.
Test Case '-[SandCoreTests.DeveloperReadyImageDefinitionTests testDeveloperReadyImageDefinitionDeclaresDefaultSandboxContract]' passed (0.000 seconds).
Test Suite 'DeveloperReadyImageDefinitionTests' passed at 2026-05-19 00:35:47.888.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'DoctorChecksTests' started at 2026-05-19 00:35:47.888.
Test Case '-[SandCoreTests.DoctorChecksTests testReportsUnsupportedHostPlatformBeforeProbingBackend]' started.
Test Case '-[SandCoreTests.DoctorChecksTests testReportsUnsupportedHostPlatformBeforeProbingBackend]' passed (0.000 seconds).
Test Case '-[SandCoreTests.DoctorChecksTests testReportsUnwritableHostMetadataAsSandboxVMPrerequisiteFailure]' started.
Test Case '-[SandCoreTests.DoctorChecksTests testReportsUnwritableHostMetadataAsSandboxVMPrerequisiteFailure]' passed (0.000 seconds).
Test Suite 'DoctorChecksTests' passed at 2026-05-19 00:35:47.888.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Suite 'FolderPolicyTests' started at 2026-05-19 00:35:47.888.
Test Case '-[SandCoreTests.FolderPolicyTests testAccessModeAliasesNormalizeToCanonicalStorage]' started.
Test Case '-[SandCoreTests.FolderPolicyTests testAccessModeAliasesNormalizeToCanonicalStorage]' passed (0.000 seconds).
Test Case '-[SandCoreTests.FolderPolicyTests testAddFolderStoresCanonicalModeResolvedPathGuestPathAndPreservesDisplayPath]' started.
Test Case '-[SandCoreTests.FolderPolicyTests testAddFolderStoresCanonicalModeResolvedPathGuestPathAndPreservesDisplayPath]' passed (0.000 seconds).
Test Case '-[SandCoreTests.FolderPolicyTests testAddingDuplicateHostFolderUpdatesExistingFolder]' started.
Test Case '-[SandCoreTests.FolderPolicyTests testAddingDuplicateHostFolderUpdatesExistingFolder]' passed (0.000 seconds).
Test Case '-[SandCoreTests.FolderPolicyTests testDefaultGuestPathDerivesFromHostFolderNameUnderWorkspace]' started.
Test Case '-[SandCoreTests.FolderPolicyTests testDefaultGuestPathDerivesFromHostFolderNameUnderWorkspace]' passed (0.000 seconds).
Test Case '-[SandCoreTests.FolderPolicyTests testDuplicateGuestPathIsRejected]' started.
Test Case '-[SandCoreTests.FolderPolicyTests testDuplicateGuestPathIsRejected]' passed (0.000 seconds).
Test Case '-[SandCoreTests.FolderPolicyTests testExplicitAsGuestPathOverrideIsStored]' started.
Test Case '-[SandCoreTests.FolderPolicyTests testExplicitAsGuestPathOverrideIsStored]' passed (0.000 seconds).
Test Case '-[SandCoreTests.FolderPolicyTests testOverlappingHostFoldersAreRejected]' started.
Test Case '-[SandCoreTests.FolderPolicyTests testOverlappingHostFoldersAreRejected]' passed (0.000 seconds).
Test Case '-[SandCoreTests.FolderPolicyTests testSymlinkRealpathIsUsedForDuplicateAndOverlapChecks]' started.
Test Case '-[SandCoreTests.FolderPolicyTests testSymlinkRealpathIsUsedForDuplicateAndOverlapChecks]' passed (0.000 seconds).
Test Suite 'FolderPolicyTests' passed at 2026-05-19 00:35:47.889.
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'HostMetadataStoreTests' started at 2026-05-19 00:35:47.889.
Test Case '-[SandCoreTests.HostMetadataStoreTests testDuplicateSandboxNameErrorIsClearForCLIOutput]' started.
Test Case '-[SandCoreTests.HostMetadataStoreTests testDuplicateSandboxNameErrorIsClearForCLIOutput]' passed (0.000 seconds).
Test Case '-[SandCoreTests.HostMetadataStoreTests testFileLifecycleMutationLockSerializesSeparateStoreInstancesSharingRoot]' started.
Test Case '-[SandCoreTests.HostMetadataStoreTests testFileLifecycleMutationLockSerializesSeparateStoreInstancesSharingRoot]' passed (0.206 seconds).
Test Case '-[SandCoreTests.HostMetadataStoreTests testFileStoreCreatesReadsUpdatesDeletesAndListsSpecsWithSchemaVersion]' started.
Test Case '-[SandCoreTests.HostMetadataStoreTests testFileStoreCreatesReadsUpdatesDeletesAndListsSpecsWithSchemaVersion]' passed (0.015 seconds).
Test Case '-[SandCoreTests.HostMetadataStoreTests testFileStoreRejectsSpecWhoseDeclaredNameDoesNotMatchRequestedName]' started.
Test Case '-[SandCoreTests.HostMetadataStoreTests testFileStoreRejectsSpecWhoseDeclaredNameDoesNotMatchRequestedName]' passed (0.002 seconds).
Test Case '-[SandCoreTests.HostMetadataStoreTests testFileWritesAreAtomicFromPublicContractPerspective]' started.
Test Case '-[SandCoreTests.HostMetadataStoreTests testFileWritesAreAtomicFromPublicContractPerspective]' passed (0.003 seconds).
Test Case '-[SandCoreTests.HostMetadataStoreTests testGlobalSandboxNameUniquenessIsRejectedByMetadataStore]' started.
Test Case '-[SandCoreTests.HostMetadataStoreTests testGlobalSandboxNameUniquenessIsRejectedByMetadataStore]' passed (0.000 seconds).
Test Case '-[SandCoreTests.HostMetadataStoreTests testLifecycleMutationLockSerializesOperations]' started.
Test Case '-[SandCoreTests.HostMetadataStoreTests testLifecycleMutationLockSerializesOperations]' passed (0.000 seconds).
Test Case '-[SandCoreTests.HostMetadataStoreTests testUnsupportedHostMetadataSchemaVersionIsRejected]' started.
Test Case '-[SandCoreTests.HostMetadataStoreTests testUnsupportedHostMetadataSchemaVersionIsRejected]' passed (0.001 seconds).
Test Suite 'HostMetadataStoreTests' passed at 2026-05-19 00:35:48.117.
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.227 (0.228) seconds
Test Suite 'LifecycleCoordinatorTests' started at 2026-05-19 00:35:48.117.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testApplyOnRunningSandboxPromptsBeforeInterruptingActiveSessions]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testApplyOnRunningSandboxPromptsBeforeInterruptingActiveSessions]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testApplyReconcilesStoredSpecThroughBackendUnderLifecycleLock]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testApplyReconcilesStoredSpecThroughBackendUnderLifecycleLock]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testApplyRejectsManualCpuEditsAgainstCreatedSpecBeforeTouchingBackend]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testApplyRejectsManualCpuEditsAgainstCreatedSpecBeforeTouchingBackend]' passed (0.002 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testApplyRejectsManualMemoryEditsAgainstCreatedSpecBeforeTouchingBackend]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testApplyRejectsManualMemoryEditsAgainstCreatedSpecBeforeTouchingBackend]' passed (0.002 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testCreateRollsBackHostMetadataWhenBackendProvisioningFails]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testCreateRollsBackHostMetadataWhenBackendProvisioningFails]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testCreateWritesSpecAndProvisionsBackendLeavingSandboxStopped]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testCreateWritesSpecAndProvisionsBackendLeavingSandboxStopped]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testDeleteCancelledByPromptDoesNotMutateBackendOrMetadata]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testDeleteCancelledByPromptDoesNotMutateBackendOrMetadata]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testDoctorPrintsConciseSuccessOutputForDailyUse]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testDoctorPrintsConciseSuccessOutputForDailyUse]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testDoctorRunsFullPrerequisiteChecksIncludingHostMetadata]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testDoctorRunsFullPrerequisiteChecksIncludingHostMetadata]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testFolderAddMutatesSpecAndAutoAppliesThroughFakeBackend]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testFolderAddMutatesSpecAndAutoAppliesThroughFakeBackend]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testFolderMutationRejectsExistingManualResourceEditsBeforeWritingOrApplying]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testFolderMutationRejectsExistingManualResourceEditsBeforeWritingOrApplying]' passed (0.002 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testFolderRemoveMutatesSpecAndAutoAppliesThroughFakeBackend]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testFolderRemoveMutatesSpecAndAutoAppliesThroughFakeBackend]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testFoldersListPrintsHostGuestAndAccessModeForAudit]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testFoldersListPrintsHostGuestAndAccessModeForAudit]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testListPrintsConciseStatusForStoredSandboxes]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testListPrintsConciseStatusForStoredSandboxes]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testLogsPrintBackendRuntimeLogsWithoutDroppingUsefulLines]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testLogsPrintBackendRuntimeLogsWithoutDroppingUsefulLines]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testNormalRunAndShellAreNotSerializedBehindLifecycleMutationLocks]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testNormalRunAndShellAreNotSerializedBehindLifecycleMutationLocks]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testRunAutoStartsStoppedSandboxAndDelegatesOpaqueCommandToBackend]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testRunAutoStartsStoppedSandboxAndDelegatesOpaqueCommandToBackend]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testRunningConfigChangeAppliesAfterPromptApproval]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testRunningConfigChangeAppliesAfterPromptApproval]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testRunningConfigChangePromptsBeforeApplyingAndLeavesSpecUntouchedWhenCancelled]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testRunningConfigChangePromptsBeforeApplyingAndLeavesSpecUntouchedWhenCancelled]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testRunOutsideAllowedFoldersWarnsAndUsesFallbackWorkingDirectory]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testRunOutsideAllowedFoldersWarnsAndUsesFallbackWorkingDirectory]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testShellAutoStartsStoppedSandboxAndUsesMappedWorkingDirectory]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testShellAutoStartsStoppedSandboxAndUsesMappedWorkingDirectory]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testShellOutsideAllowedFoldersWarnsAndUsesFallbackWorkingDirectory]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testShellOutsideAllowedFoldersWarnsAndUsesFallbackWorkingDirectory]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testSpecPrintsActiveSandboxSpec]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testSpecPrintsActiveSandboxSpec]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testStartStopAndDeleteAreLifecycleMutationsAndUpdateBackendState]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testStartStopAndDeleteAreLifecycleMutationsAndUpdateBackendState]' passed (0.000 seconds).
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testStatusPrintsUsefulConfigAndRuntimeStateWithoutRawBackendDump]' started.
Test Case '-[SandCoreTests.LifecycleCoordinatorTests testStatusPrintsUsefulConfigAndRuntimeStateWithoutRawBackendDump]' passed (0.000 seconds).
Test Suite 'LifecycleCoordinatorTests' passed at 2026-05-19 00:35:48.126.
	 Executed 25 tests, with 0 failures (0 unexpected) in 0.008 (0.009) seconds
Test Suite 'PiWorkloadCredentialBoundaryValidationTests' started at 2026-05-19 00:35:48.126.
Test Case '-[SandCoreTests.PiWorkloadCredentialBoundaryValidationTests testPiCredentialBoundaryValidationScriptDocumentsRealBackendUnauthenticatedChecks]' started.
Test Case '-[SandCoreTests.PiWorkloadCredentialBoundaryValidationTests testPiCredentialBoundaryValidationScriptDocumentsRealBackendUnauthenticatedChecks]' passed (0.001 seconds).
Test Suite 'PiWorkloadCredentialBoundaryValidationTests' passed at 2026-05-19 00:35:48.127.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'PromptConfirmationTests' started at 2026-05-19 00:35:48.127.
Test Case '-[SandCoreTests.PromptConfirmationTests testDestructivePromptRequiresExplicitYes]' started.
Test Case '-[SandCoreTests.PromptConfirmationTests testDestructivePromptRequiresExplicitYes]' passed (0.000 seconds).
Test Suite 'PromptConfirmationTests' passed at 2026-05-19 00:35:48.127.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Suite 'SandboxSpecTests' started at 2026-05-19 00:35:48.127.
Test Case '-[SandCoreTests.SandboxSpecTests testCpuAndMemoryEditsAfterCreationAreRejectedAtSpecContractLevel]' started.
Test Case '-[SandCoreTests.SandboxSpecTests testCpuAndMemoryEditsAfterCreationAreRejectedAtSpecContractLevel]' passed (0.000 seconds).
Test Case '-[SandCoreTests.SandboxSpecTests testCreateFromUserAuthoredSpecParsesExplicitImageResourcesAndFolders]' started.
Test Case '-[SandCoreTests.SandboxSpecTests testCreateFromUserAuthoredSpecParsesExplicitImageResourcesAndFolders]' passed (0.000 seconds).
Test Case '-[SandCoreTests.SandboxSpecTests testGeneratedSpecRendersAndParsesBackToSameContract]' started.
Test Case '-[SandCoreTests.SandboxSpecTests testGeneratedSpecRendersAndParsesBackToSameContract]' passed (0.000 seconds).
Test Case '-[SandCoreTests.SandboxSpecTests testGeneratedSpecUsesV1DefaultsAndNoUnsupportedFutureFields]' started.
Test Case '-[SandCoreTests.SandboxSpecTests testGeneratedSpecUsesV1DefaultsAndNoUnsupportedFutureFields]' passed (0.000 seconds).
Test Case '-[SandCoreTests.SandboxSpecTests testSandboxNameValidation]' started.
Test Case '-[SandCoreTests.SandboxSpecTests testSandboxNameValidation]' passed (0.000 seconds).
Test Case '-[SandCoreTests.SandboxSpecTests testUnsupportedV1FieldsSuchAsInboundNetworkingAreRejected]' started.
Test Case '-[SandCoreTests.SandboxSpecTests testUnsupportedV1FieldsSuchAsInboundNetworkingAreRejected]' passed (0.000 seconds).
Test Suite 'SandboxSpecTests' passed at 2026-05-19 00:35:48.128.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
Test Suite 'WorkingDirectoryMapperTests' started at 2026-05-19 00:35:48.128.
Test Case '-[SandCoreTests.WorkingDirectoryMapperTests testCwdOutsideAllowedFoldersUsesFallbackWithWarning]' started.
Test Case '-[SandCoreTests.WorkingDirectoryMapperTests testCwdOutsideAllowedFoldersUsesFallbackWithWarning]' passed (0.000 seconds).
Test Case '-[SandCoreTests.WorkingDirectoryMapperTests testMapsCwdInsideAllowedFolderToGuestPath]' started.
Test Case '-[SandCoreTests.WorkingDirectoryMapperTests testMapsCwdInsideAllowedFolderToGuestPath]' passed (0.000 seconds).
Test Case '-[SandCoreTests.WorkingDirectoryMapperTests testMapsNestedCwdInsideAllowedFolderToNestedGuestPath]' started.
Test Case '-[SandCoreTests.WorkingDirectoryMapperTests testMapsNestedCwdInsideAllowedFolderToNestedGuestPath]' passed (0.000 seconds).
Test Case '-[SandCoreTests.WorkingDirectoryMapperTests testMapsSymlinkedCwdUsingResolvedPath]' started.
Test Case '-[SandCoreTests.WorkingDirectoryMapperTests testMapsSymlinkedCwdUsingResolvedPath]' passed (0.000 seconds).
Test Suite 'WorkingDirectoryMapperTests' passed at 2026-05-19 00:35:48.128.
	 Executed 4 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Suite 'sandPackageTests.xctest' passed at 2026-05-19 00:35:48.128.
	 Executed 77 tests, with 0 failures (0 unexpected) in 0.246 (0.250) seconds
Test Suite 'All tests' passed at 2026-05-19 00:35:48.128.
	 Executed 77 tests, with 0 failures (0 unexpected) in 0.246 (0.251) seconds
􀟈  Test run started.
􀄵  Testing Library Version: 1501
􀄵  Target Platform: arm64e-apple-macos14.0
􁁛  Test run with 0 tests in 0 suites passed after 0.001 seconds.
[exit 0]
```

## sand doctor

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand doctor
sand doctor: all Sandbox VM prerequisites OK
[exit 0]
```

## Create Sandbox VM

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand create sandv1accept519
[exit 0]
```

## sand list after create

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand list
mybox	running	sand/developer-ready:ubuntu-lts	1 folders
sandv1accept519	stopped	sand/developer-ready:ubuntu-lts	0 folders
[exit 0]
```

## sand status after create

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 status
name: sandv1accept519
state: stopped
image: sand/developer-ready:ubuntu-lts
resources: 4 CPUs, 8GB memory
allowedFolders: 0
[exit 0]
```

## sand spec after create

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 spec
schemaVersion: 1
name: sandv1accept519
image: sand/developer-ready:ubuntu-lts
resources:
  cpus: 4
  memory: 8GB
allowedFolders:
  []
[exit 0]
```

## Add read-write project Allowed Folder

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand folders add sandv1accept519 /tmp/sand-v1-acceptance-20260519/project rw --as /workspace/project
[exit 0]
```

## Add read-only reference Allowed Folder

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand folders add sandv1accept519 /tmp/sand-v1-acceptance-20260519/reference ro --as /workspace/reference
[exit 0]
```

## Allowed Folder audit

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand folders list sandv1accept519
Host Path	Guest Path	Access Mode
/tmp/sand-v1-acceptance-20260519/project	/workspace/project	read-write
/tmp/sand-v1-acceptance-20260519/reference	/workspace/reference	read-only
[exit 0]
```

## Sandbox spec after folders

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 spec
schemaVersion: 1
name: sandv1accept519
image: sand/developer-ready:ubuntu-lts
resources:
  cpus: 4
  memory: 8GB
allowedFolders:
  - hostPath: /tmp/sand-v1-acceptance-20260519/project
    resolvedHostPath: /tmp/sand-v1-acceptance-20260519/project
    guestPath: /workspace/project
    accessMode: read-write
  - hostPath: /tmp/sand-v1-acceptance-20260519/reference
    resolvedHostPath: /tmp/sand-v1-acceptance-20260519/reference
    guestPath: /workspace/reference
    accessMode: read-only
[exit 0]
```

## Workload Command from mapped Host Mac cwd

```console
$ cd /tmp/sand-v1-acceptance-20260519/project/subdir && /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 run bash -lc printf "guest-pwd=%s\\n" "$PWD"; printf "input="; cat input.txt; printf "reference="; cat /workspace/reference/reference.txt
guest-pwd=/workspace/project/subdir
input=project-data
reference=reference-data
[exit 0]
```

## Interactive Sandbox Session, Sandbox User, passwordless sudo

```console
$ cd /tmp/sand-v1-acceptance-20260519/project/subdir && /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 shell
sandbox@sandv1accept519:/workspace/project/subdir$ printf 'interactive-pwd=%s\n'
 "$PWD"; printf 'interactive-user='; whoami; sudo -n true && echo 'passwordless-
sudo=ok'; echo 'shell-marker' > interactive-shell.txt
interactive-pwd=/workspace/project/subdir
interactive-user=sandbox
passwordless-sudo=ok
sandbox@sandv1accept519:/workspace/project/subdir$
```

## Concurrent session while interactive shell remained open

```console
$ cd /tmp/sand-v1-acceptance-20260519/project/subdir && /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 run bash -lc 'echo concurrent-run-ok; pwd; whoami'
concurrent-run-ok
/workspace/project/subdir
sandbox
__EXIT_CODE__:0
```

## Guest write then Host-Safe File Ownership check

```console
$ cd /tmp/sand-v1-acceptance-20260519/project/subdir && /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 run bash -lc echo guest-write > host-owned.txt && ls -ln host-owned.txt && cat host-owned.txt
-rw-r--r-- 1 1001 1001 12 May 19 07:37 host-owned.txt
guest-write
[exit 0]
```

## Host Mac ownership after guest write

```console
$ id -un; id -gn; stat -f '%Su:%Sg %u:%g %N' '/tmp/sand-v1-acceptance-20260519/project/subdir/host-owned.txt'; cat '/tmp/sand-v1-acceptance-20260519/project/subdir/host-owned.txt'
onorbumbum
staff
onorbumbum:wheel 501:0 /tmp/sand-v1-acceptance-20260519/project/subdir/host-owned.txt
guest-write
[exit 0]
```

## Write Guest State marker

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 run bash -lc echo persisted-state > "$HOME/.pi/persist.txt" && readlink "$HOME/.pi" && cat "$HOME/.pi/persist.txt"
Current directory is not inside an Allowed Folder; starting in /workspace.
/state/sandbox/.pi
persisted-state
[exit 0]
```

## Stop Sandbox VM

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 stop
[exit 0]
```

## Status after stop

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 status
name: sandv1accept519
state: stopped
image: sand/developer-ready:ubuntu-lts
resources: 4 CPUs, 8GB memory
allowedFolders: 2
[exit 0]
```

## Start Sandbox VM

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 start
[exit 0]
```

## Guest State persists after start

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 run bash -lc cat "$HOME/.pi/persist.txt"
Current directory is not inside an Allowed Folder; starting in /workspace.
persisted-state
[exit 0]
```

## Manual Sandbox Spec edit

```console
$ cat >> /Users/onorbumbum/.sand/specs/sandv1accept519.yaml <<'YAML'
  - hostPath: /tmp/sand-v1-acceptance-20260519/manual
    resolvedHostPath: /tmp/sand-v1-acceptance-20260519/manual
    guestPath: /workspace/manual
    accessMode: read-only
YAML
```

## Apply manual spec edit with running-Sandbox confirmation

```console
$ printf 'y\n' | '/Users/onorbumbum/_PROJECTS/sand/.build/debug/sand' apply 'sandv1accept519'
Apply changes to running Sandbox VM sandv1accept519? Proceed? [y/N] [exit 0]
```

## Spec after manual reconciliation

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 spec
schemaVersion: 1
name: sandv1accept519
image: sand/developer-ready:ubuntu-lts
resources:
  cpus: 4
  memory: 8GB
allowedFolders:
  - hostPath: /tmp/sand-v1-acceptance-20260519/project
    resolvedHostPath: /tmp/sand-v1-acceptance-20260519/project
    guestPath: /workspace/project
    accessMode: read-write
  - hostPath: /tmp/sand-v1-acceptance-20260519/reference
    resolvedHostPath: /tmp/sand-v1-acceptance-20260519/reference
    guestPath: /workspace/reference
    accessMode: read-only
  - hostPath: /tmp/sand-v1-acceptance-20260519/manual
    resolvedHostPath: /tmp/sand-v1-acceptance-20260519/manual
    guestPath: /workspace/manual
    accessMode: read-only
[exit 0]
```

## Manual spec mount reconciled into backend

```console
$ cd /tmp/sand-v1-acceptance-20260519/manual && /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 run bash -lc pwd; cat manual.txt
/workspace/manual
manual-data
[exit 0]
```

## View Sandbox VM logs

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 logs
No logs available for Sandbox VM sandv1accept519.
[exit 0]
```

## Out-of-scope reset command absent

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand reset sandv1accept519
sand: unsupported command: reset
[exit 1]
```

## Out-of-scope Pi shortcut command absent

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 pi
sand: unsupported sandbox action: pi
[exit 1]
```

## Out-of-scope inbound networking config absent

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand create sandv1inbound --inbound 8080:8080
sand: unsupported option: --inbound
[exit 1]
```

## Out-of-scope editor integration absent

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 edit
sand: unsupported sandbox action: edit
[exit 1]
```

## Out-of-scope shell completion absent

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand completion
sand: missing sandbox action
[exit 1]
```

## Out-of-scope default implicit selection absent

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand status
sand: missing sandbox action
[exit 1]
```

## Out-of-scope project-local implicit selection absent

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand run echo hi
sand: unsupported sandbox action: echo
[exit 1]
```

## Host pi mount and credential forwarding absent inside Sandbox

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand sandv1accept519 run bash -lc test "$(readlink "$HOME/.pi")" = /state/sandbox/.pi; test ! -e /Users; test ! -e /host; test ! -S /run/host-services/ssh-auth.sock; test -z "${SSH_AUTH_SOCK:-}"; echo credential-boundary-ok
Current directory is not inside an Allowed Folder; starting in /workspace.
credential-boundary-ok
[exit 0]
```

## No fake backend or env backend selector in product sources

```console
$ cd '/Users/onorbumbum/_PROJECTS/sand' && grep -R -n -E 'FakeSandboxBackend|RecordingSandboxBackend|ProcessInfo\.processInfo\.environment|SAND_BACKEND|MOCK|IN_MEMORY' Sources || true
[exit 0]
```

## No raw Apple container string outside backend adapter boundary

```console
$ cd '/Users/onorbumbum/_PROJECTS/sand' && find Sources -name '*.swift' ! -path '*/Backend/AppleContainerCLIBackend.swift' -print0 | xargs -0 grep -n 'container' || true
[exit 0]
```

## Delete Sandbox VM

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand delete sandv1accept519 --force
[exit 0]
```

## sand list after delete

```console
$ /Users/onorbumbum/_PROJECTS/sand/.build/debug/sand list
mybox	running	sand/developer-ready:ubuntu-lts	1 folders
[exit 0]
```

## Metadata cleanup after delete

```console
$ test ! -e '/Users/onorbumbum/.sand/specs/sandv1accept519.yaml'; test ! -e '/Users/onorbumbum/.sand/created-specs/sandv1accept519.yaml'; echo metadata-cleaned
metadata-cleaned
[exit 0]
```

## Backend runtime cleanup after delete

```console
$ container inspect 'sandv1accept519'; echo inspect-exit:$?; container volume inspect 'sand-state-sandv1accept519'; echo volume-inspect-exit:$?
[]
inspect-exit:0
Error: volume 'sand-state-sandv1accept519' not found
volume-inspect-exit:1
[exit 0]
```

## Acceptance conclusion

PASS: The full v1 workflow was run against the real `sand` executable and Apple `container` backend. The only expected non-zero exits are the explicit out-of-scope command absence checks and direct backend cleanup probes after deletion.
