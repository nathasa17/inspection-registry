// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract InspectionRegistryV2 is AccessControl {
    enum Status { NONE, SUBMITTED, APPROVED, REVOKED }

    struct Record {
        address vendor;
        bytes32 evidenceHash;
        Status status;
        uint64 updatedAt;
    }

    bytes32 public constant VENDOR_ROLE = keccak256("VENDOR_ROLE");
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");

    mapping(bytes32 => Record) public records;
    mapping(bytes32 => bytes32) public revocationReasons;

    error ZeroAddress();
    error EmptyId();
    error EmptyEvidence();
    error EmptyReason();
    error InvalidStatus(bytes32 id, Status expected, Status actual);
    // Pilihan A: pembuat record tidak boleh menyetujui recordnya sendiri
    error SelfApprovalNotAllowed();

    event InspectionSubmitted(
        bytes32 indexed id, address indexed vendor, bytes32 evidenceHash
    );
    event StatusChanged(
        bytes32 indexed id, Status from, Status to, address indexed actor
    );
    event InspectionRevoked(
        bytes32 indexed id, bytes32 reasonHash, address indexed actor
    );

    constructor(address admin_, address regulator_) {
        if (admin_ == address(0) || regulator_ == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(REGULATOR_ROLE, regulator_);
    }

    modifier atStatus(bytes32 id, Status expected) {
        Status actual = records[id].status;
        if (actual != expected) revert InvalidStatus(id, expected, actual);
        _;
    }

    function submit(bytes32 id, bytes32 evidenceHash)
        external onlyRole(VENDOR_ROLE) atStatus(id, Status.NONE)
    {
        if (id == bytes32(0)) revert EmptyId();
        if (evidenceHash == bytes32(0)) revert EmptyEvidence();

        records[id] = Record({
            vendor: msg.sender,
            evidenceHash: evidenceHash,
            status: Status.SUBMITTED,
            updatedAt: uint64(block.timestamp)
        });

        emit InspectionSubmitted(id, msg.sender, evidenceHash);
        emit StatusChanged(id, Status.NONE, Status.SUBMITTED, msg.sender);
    }

    function approve(bytes32 id)
        external atStatus(id, Status.SUBMITTED)
    {
        Record storage record = records[id];

        if (msg.sender == record.vendor) revert SelfApprovalNotAllowed();

        record.status = Status.APPROVED;
        record.updatedAt = uint64(block.timestamp);

        emit StatusChanged(id, Status.SUBMITTED, Status.APPROVED, msg.sender);
    }

    // PERBAIKAN: onlyRole(REGULATOR_ROLE) sebelumnya hilang di fungsi ini
    function revoke(bytes32 id, bytes32 reasonHash)
        external onlyRole(REGULATOR_ROLE) atStatus(id, Status.APPROVED)
    {
        if (reasonHash == bytes32(0)) revert EmptyReason();

        Record storage record = records[id];
        record.status = Status.REVOKED;
        record.updatedAt = uint64(block.timestamp);
        revocationReasons[id] = reasonHash;

        emit StatusChanged(id, Status.APPROVED, Status.REVOKED, msg.sender);
        emit InspectionRevoked(id, reasonHash, msg.sender);
    }
}
