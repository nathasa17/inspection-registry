// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {InspectionRegistryV2} from "./InspectionRegistryV2.sol";

// Interface kecil untuk fasilitas TEST Hardhat. Bukan dependency kontrak produksi.
interface VmWeek10 {
    struct Log { bytes32[] topics; bytes data; address emitter; }
    function prank(address sender) external;
    function warp(uint256 timestamp) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory logs);
}

contract InspectionRegistryV2Test {
    VmWeek10 constant vm = VmWeek10(address(uint160(uint256(keccak256("hevm cheat code")))));
    InspectionRegistryV2 registry;

    address constant VENDOR = address(0xBEEF);
    address constant REGULATOR = address(0xCAFE);
    address constant STRANGER = address(0xBAD);

    bytes32 constant ID = keccak256("LIFT-01");
    bytes32 constant EVIDENCE = keccak256("report-v1");
    bytes32 constant REASON = keccak256("inspection-invalid");

    bytes32 constant VENDOR_ROLE = keccak256("VENDOR_ROLE");
    bytes32 constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");

    function setUp() public {
        vm.warp(1000);
        registry = new InspectionRegistryV2(address(this), REGULATOR);
        registry.grantRole(VENDOR_ROLE, VENDOR);
    }

    function _submit() internal {
        vm.prank(VENDOR);
        registry.submit(ID, EVIDENCE);
    }

    function _approve() internal {
        vm.prank(REGULATOR);
        registry.approve(ID);
    }

    function _snapshot(bytes32 id) internal view returns (bytes32) {
        (address vendor, bytes32 evidence, InspectionRegistryV2.Status status, uint64 updatedAt) = registry.records(id);
        return keccak256(abi.encode(vendor, evidence, status, updatedAt));
    }

    // Membandingkan SELURUH error data, bukan hanya success == false.
    function _expectError(bool success, bytes memory actual, bytes memory expected) internal pure {
        require(!success, "call should revert");
        require(keccak256(actual) == keccak256(expected), "wrong error data");
    }

    function _unauthorized(address caller, bytes32 role) internal pure returns (bytes memory) {
        return abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", caller, role);
    }

    function testSubmitStoresRecord() public {
        _submit();
        (address vendor, bytes32 evidence, InspectionRegistryV2.Status status, uint64 updatedAt) = registry.records(ID);
        require(vendor == VENDOR, "wrong vendor");
        require(evidence == EVIDENCE, "wrong evidence");
        require(status == InspectionRegistryV2.Status.SUBMITTED, "wrong state");
        require(updatedAt == 1000, "wrong timestamp");
    }

    function testHappyPathThroughRevoke() public {
        _submit();
        _approve();
        vm.prank(REGULATOR);
        registry.revoke(ID, REASON);
        
        (, bytes32 evidence, InspectionRegistryV2.Status status,) = registry.records(ID);
        require(status == InspectionRegistryV2.Status.REVOKED, "not revoked");
        require(evidence == EVIDENCE, "evidence overwritten");
        require(registry.revocationReasons(ID) == REASON, "reason not stored");
    }

    function testUnregisteredVendorCannotSubmit() public {
        bytes32 beforeRecord = _snapshot(ID);
        vm.prank(STRANGER);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.submit, (ID, EVIDENCE)));
        _expectError(ok, data, _unauthorized(STRANGER, VENDOR_ROLE));
        require(_snapshot(ID) == beforeRecord, "state changed");
    }

    function testVendorCannotApprove() public {
        _submit();
        bytes32 beforeRecord = _snapshot(ID);
        vm.warp(2000);
        vm.prank(VENDOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.approve, (ID)));
        _expectError(ok, data, _unauthorized(VENDOR, REGULATOR_ROLE));
        require(_snapshot(ID) == beforeRecord, "state changed");
    }

    function testApproveUnknownRevertsWithExactError() public {
        vm.prank(REGULATOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.approve, (ID)));
        _expectError(ok, data, abi.encodeWithSelector(InspectionRegistryV2.InvalidStatus.selector, ID, InspectionRegistryV2.Status.SUBMITTED, InspectionRegistryV2.Status.NONE));
    }

    function testDuplicateCannotOverwriteRecord() public {
        _submit();
        bytes32 beforeRecord = _snapshot(ID);
        vm.warp(2000);
        vm.prank(VENDOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.submit, (ID, keccak256("replacement"))));
        _expectError(ok, data, abi.encodeWithSelector(InspectionRegistryV2.InvalidStatus.selector, ID, InspectionRegistryV2.Status.NONE, InspectionRegistryV2.Status.SUBMITTED));
        require(_snapshot(ID) == beforeRecord, "record overwritten");
    }

    function testEmptyIdReverts() public {
        vm.prank(VENDOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.submit, (bytes32(0), EVIDENCE)));
        _expectError(ok, data, abi.encodeWithSelector(InspectionRegistryV2.EmptyId.selector));
    }

    function testEmptyEvidenceReverts() public {
        vm.prank(VENDOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.submit, (ID, bytes32(0))));
        _expectError(ok, data, abi.encodeWithSelector(InspectionRegistryV2.EmptyEvidence.selector));
    }

    function testRevokeBeforeApprovalReverts() public {
        _submit();
        vm.prank(REGULATOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.revoke, (ID, REASON)));
        _expectError(ok, data, abi.encodeWithSelector(InspectionRegistryV2.InvalidStatus.selector, ID, InspectionRegistryV2.Status.APPROVED, InspectionRegistryV2.Status.SUBMITTED));
    }

    function testEmptyReasonLeavesApprovedRecordUnchanged() public {
        _submit();
        _approve();
        bytes32 beforeRecord = _snapshot(ID);
        vm.warp(2000);
        vm.prank(REGULATOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.revoke, (ID, bytes32(0))));
        _expectError(ok, data, abi.encodeWithSelector(InspectionRegistryV2.EmptyReason.selector));
        require(_snapshot(ID) == beforeRecord, "record changed");
        require(registry.revocationReasons(ID) == bytes32(0), "reason changed");
    }

    function testRevokedRecordCannotBeApprovedAgain() public {
        _submit();
        _approve();
        vm.prank(REGULATOR);
        registry.revoke(ID, REASON);
        
        vm.prank(REGULATOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.approve, (ID)));
        _expectError(ok, data, abi.encodeWithSelector(InspectionRegistryV2.InvalidStatus.selector, ID, InspectionRegistryV2.Status.SUBMITTED, InspectionRegistryV2.Status.REVOKED));
    }

    function testVendorCannotGrantItselfRegulatorRole() public {
        vm.prank(VENDOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.grantRole, (REGULATOR_ROLE, VENDOR)));
        _expectError(ok, data, _unauthorized(VENDOR, bytes32(0)));
        require(!registry.hasRole(REGULATOR_ROLE, VENDOR), "privilege escalation");
    }

    function testRevokedVendorCannotSubmitNewRecord() public {
        _submit();
        registry.revokeRole(VENDOR_ROLE, VENDOR);
        
        vm.prank(VENDOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.submit, (keccak256("LIFT-02"), EVIDENCE)));
        _expectError(ok, data, _unauthorized(VENDOR, VENDOR_ROLE));
        
        (address originalVendor, , InspectionRegistryV2.Status status,) = registry.records(ID);
        require(originalVendor == VENDOR, "history changed");
        require(status == InspectionRegistryV2.Status.SUBMITTED, "history state changed");
    }

    function testAdminCanReplaceRegulator() public {
        _submit();
        address nextRegulator = address(0xD00D);
        registry.revokeRole(REGULATOR_ROLE, REGULATOR);
        registry.grantRole(REGULATOR_ROLE, nextRegulator);
        
        vm.prank(REGULATOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.approve, (ID)));
        _expectError(ok, data, _unauthorized(REGULATOR, REGULATOR_ROLE));
        
        vm.prank(nextRegulator);
        registry.approve(ID);
        (,, InspectionRegistryV2.Status status,) = registry.records(ID);
        require(status == InspectionRegistryV2.Status.APPROVED, "new regulator failed");
    }

    function testApprovalEmitsExactAuditEvent() public {
        _submit();
        vm.recordLogs();
        _approve();
        
        VmWeek10.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1, "expected one approval event");
        require(logs[0].emitter == address(registry), "wrong emitter");
        require(logs[0].topics.length == 3, "wrong topics count");
        
        require(logs[0].topics[0] == keccak256("StatusChanged(bytes32,uint8,uint8,address)"), "wrong signature");
        require(logs[0].topics[1] == ID, "wrong id");
        require(logs[0].topics[2] == bytes32(uint256(uint160(REGULATOR))), "wrong actor");
        
        (uint8 from, uint8 to) = abi.decode(logs[0].data, (uint8, uint8));
        require(from == 1 && to == 2, "wrong transition");
        
        (,, InspectionRegistryV2.Status status,) = registry.records(ID);
        require(status == InspectionRegistryV2.Status.APPROVED, "wrong final state");
    }

    function testUnauthorizedCallLeavesNoContractLogs() public {
        _submit();
        vm.recordLogs();
        
        vm.prank(VENDOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.approve, (ID)));
        _expectError(ok, data, _unauthorized(VENDOR, REGULATOR_ROLE));
        
        VmWeek10.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 0, "unexpected contract log");
    }

    function testCannotApproveOwnSubmission() public {
        registry.grantRole(REGULATOR_ROLE, VENDOR);
        _submit();
        bytes32 beforeRecord = _snapshot(ID);
        vm.warp(2000);

        vm.prank(VENDOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.approve, (ID)));

        _expectError(ok, data, abi.encodeWithSelector(InspectionRegistryV2.SelfApprovalNotAllowed.selector));
        require(_snapshot(ID) == beforeRecord, "record changed");
    }

    function testOtherRegulatorCanApprove() public {
        registry.grantRole(REGULATOR_ROLE, VENDOR);
        _submit();
        
        _approve(); 
        
        (,, InspectionRegistryV2.Status status,) = registry.records(ID);
        require(status == InspectionRegistryV2.Status.APPROVED, "Approval by other regulator failed");
    }

    // Test tambahan: menutup celah kontrol akses pada revoke()
    function testVendorCannotRevoke() public {
        _submit();
        _approve();
        bytes32 beforeRecord = _snapshot(ID);
        vm.warp(2000);

        vm.prank(VENDOR);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.revoke, (ID, REASON)));

        _expectError(ok, data, _unauthorized(VENDOR, REGULATOR_ROLE));
        require(_snapshot(ID) == beforeRecord, "record changed");
        require(registry.revocationReasons(ID) == bytes32(0), "reason changed");
    }

    function testStrangerCannotRevoke() public {
        _submit();
        _approve();
        bytes32 beforeRecord = _snapshot(ID);

        vm.prank(STRANGER);
        (bool ok, bytes memory data) = address(registry).call(abi.encodeCall(registry.revoke, (ID, REASON)));

        _expectError(ok, data, _unauthorized(STRANGER, REGULATOR_ROLE));
        require(_snapshot(ID) == beforeRecord, "record changed");
    }
}
