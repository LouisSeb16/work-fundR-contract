// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EscrowService {
    struct Job {
        address payable client;
        address payable serviceProvider;
        uint256 totalPayment;
        uint256 initialPayment;
        uint256 finalPayment;
        bool isInitialPaid;
        bool isCompleted;
        bool isFinalPaid;
    }

    mapping(uint256 => Job) public jobs;
    uint256 public jobCounter;

    // Events
    event JobCreated(uint256 jobId, address client, address serviceProvider, uint256 totalPayment);
    event InitialPaymentReleased(uint256 jobId);
    event FinalPaymentReleased(uint256 jobId);
    event JobCompleted(uint256 jobId);
    event RefundIssued(uint256 jobId);

    // Modifier to restrict actions to client
    modifier onlyClient(uint256 _jobId) {
        require(msg.sender == jobs[_jobId].client, "Only client can perform this action.");
        _;
    }

    // Modifier to restrict actions to service provider
    modifier onlyServiceProvider(uint256 _jobId) {
        require(msg.sender == jobs[_jobId].serviceProvider, "Only service provider can perform this action.");
        _;
    }

    // Modifier to ensure job exists
    modifier jobExists(uint256 _jobId) {
        require(_jobId < jobCounter, "Job does not exist.");
        _;
    }

    // Create a new job with agreed payment terms
    function createJob(address payable _serviceProvider, uint256 _totalPayment, uint256 _initialPayment) public payable {
        require(msg.value == _initialPayment, "Initial payment must be sent to contract");
        require(_initialPayment <= _totalPayment, "Initial payment exceeds total payment");

        jobCounter++;
        jobs[jobCounter] = Job({
            client: payable(msg.sender),
            serviceProvider: _serviceProvider,
            totalPayment: _totalPayment,
            initialPayment: _initialPayment,
            finalPayment: _totalPayment - _initialPayment,
            isInitialPaid: false,
            isCompleted: false,
            isFinalPaid: false
        });

        emit JobCreated(jobCounter, msg.sender, _serviceProvider, _totalPayment);
    }

    // Release initial payment to service provider
    function releaseInitialPayment(uint256 _jobId) public jobExists(_jobId) onlyClient(_jobId) {
        Job storage job = jobs[_jobId];
        require(!job.isInitialPaid, "Initial payment already released");
        
        job.serviceProvider.transfer(job.initialPayment);
        job.isInitialPaid = true;
        
        emit InitialPaymentReleased(_jobId);
    }

    // Mark job as complete
    function markJobComplete(uint256 _jobId) public jobExists(_jobId) onlyServiceProvider(_jobId) {
        Job storage job = jobs[_jobId];
        require(!job.isCompleted, "Job already marked complete");
        
        job.isCompleted = true;
        
        emit JobCompleted(_jobId);
    }

    // Release final payment to service provider
    function releaseFinalPayment(uint256 _jobId) public jobExists(_jobId) onlyClient(_jobId) {
        Job storage job = jobs[_jobId];
        require(job.isCompleted, "Job not marked as complete");
        require(!job.isFinalPaid, "Final payment already released");

        job.serviceProvider.transfer(job.finalPayment);
        job.isFinalPaid = true;

        emit FinalPaymentReleased(_jobId);
    }

    // Request a refund (only if service provider agrees)
    function requestRefund(uint256 _jobId) public jobExists(_jobId) onlyClient(_jobId) {
        Job storage job = jobs[_jobId];
        require(!job.isCompleted, "Cannot refund after job is completed");

        uint256 refundAmount = job.initialPayment;
        job.client.transfer(refundAmount);
        job.isInitialPaid = false;

        emit RefundIssued(_jobId);
    }
}
