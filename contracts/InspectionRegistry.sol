// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract InspectionRegistry {
    enum Status {
        NONE,
        SUBMITTED,
        APPROVED,
        REVOKED
    }

    struct Record {
        address vendor;
        bytes32 evidenceHash;
        Status status;
        uint64 updatedAt;
    }

    address public immutable regulator;
    mapping(bytes32 => Record) public records;

    event InspectionSubmitted(
        bytes32 indexed id,
        address indexed vendor,
        bytes32 evidenceHash
    );

    event StatusChanged(
        bytes32 indexed id,
        Status status
    );

    event InspectionRevoked(
        bytes32 indexed id,
        bytes32 reasonHash
    );

    error Unauthorized();
    error InvalidStatus();
    error EmptyEvidence();
    error EmptyReason();

    constructor(address regulator_) {
        require(regulator_ != address(0), "zero regulator");
        regulator = regulator_;
    }

    function submit(bytes32 id, bytes32 evidenceHash) external {
        if (evidenceHash == bytes32(0)) revert EmptyEvidence();

        Record storage record = records[id];
        if (record.status != Status.NONE) revert InvalidStatus();

        record.vendor = msg.sender;
        record.evidenceHash = evidenceHash;
        record.status = Status.SUBMITTED;
        record.updatedAt = uint64(block.timestamp);

        emit InspectionSubmitted(id, msg.sender, evidenceHash);
    }

    function approve(bytes32 id) external {
        if (msg.sender != regulator) revert Unauthorized();

        Record storage record = records[id];
        if (record.status != Status.SUBMITTED) revert InvalidStatus();

        record.status = Status.APPROVED;
        record.updatedAt = uint64(block.timestamp);

        emit StatusChanged(id, Status.APPROVED);
    }

    function revoke(bytes32 id, bytes32 reasonHash) external {
        if (msg.sender != regulator) revert Unauthorized();
        if (reasonHash == bytes32(0)) revert EmptyReason();

        Record storage record = records[id];
        if (record.status != Status.APPROVED) revert InvalidStatus();

        record.status = Status.REVOKED;
        record.updatedAt = uint64(block.timestamp);

        emit StatusChanged(id, Status.REVOKED);
        emit InspectionRevoked(id, reasonHash);
    }
}