// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InspectionRegistry.sol";

contract NonRegulatorCaller {
    function approve(
        InspectionRegistry registry,
        bytes32 id
    ) external {
        registry.approve(id);
    }
}

contract InspectionRegistryTest {
    InspectionRegistry registry;
    bytes32 id = keccak256("LIFT-01");
    bytes32 evidence = keccak256("report-v1");
    bytes32 reason = keccak256("safety-issue");

    function setUp() public {
        registry = new InspectionRegistry(address(this));
    }

    function testSubmitThenApprove() public {
        registry.submit(id, evidence);
        registry.approve(id);

        (
            address vendor,
            bytes32 storedEvidence,
            InspectionRegistry.Status status,
            uint64 updatedAt
        ) = registry.records(id);

        require(vendor == address(this), "wrong vendor");
        require(storedEvidence == evidence, "wrong evidence");
        require(
            status == InspectionRegistry.Status.APPROVED,
            "record should be approved"
        );
        require(updatedAt > 0, "timestamp should be set");
    }

    function testApproveUnknownReverts() public {
        (bool success, ) = address(registry).call(
            abi.encodeCall(registry.approve, (id))
        );
        require(!success, "approve unknown must revert");
    }

    function testDuplicateSubmissionReverts() public {
        registry.submit(id, evidence);
        (bool success, ) = address(registry).call(
            abi.encodeCall(registry.submit, (id, evidence))
        );
        require(!success, "duplicate submit must revert");
    }

    function testNonRegulatorCannotApprove() public {
        registry.submit(id, evidence);
        NonRegulatorCaller caller = new NonRegulatorCaller();

        (bool success, ) = address(caller).call(
            abi.encodeCall(caller.approve, (registry, id))
        );
        require(!success, "non-regulator must not approve");

        (, , InspectionRegistry.Status status, ) = registry.records(id);
        require(
            status == InspectionRegistry.Status.SUBMITTED,
            "state must remain submitted"
        );
    }

    function testRevokeWithReasonSuccess() public {
        registry.submit(id, evidence);
        registry.approve(id);
        registry.revoke(id, reason);

        (, , InspectionRegistry.Status status, ) = registry.records(id);
        require(
            status == InspectionRegistry.Status.REVOKED,
            "record should be revoked"
        );
    }

    function testRevokeEmptyReasonReverts() public {
        registry.submit(id, evidence);
        registry.approve(id);

        (bool success, ) = address(registry).call(
            abi.encodeCall(registry.revoke, (id, bytes32(0)))
        );
        require(!success, "empty reason must revert");

        (, , InspectionRegistry.Status status, ) = registry.records(id);
        require(
            status == InspectionRegistry.Status.APPROVED,
            "state must remain approved"
        );
    }
}
