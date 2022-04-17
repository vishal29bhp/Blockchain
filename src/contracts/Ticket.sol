// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.6 < 0.9.0;

import "../libraries/SharedStructs.sol";
import "../interfaces/FlightInterface.sol";
import "../interfaces/TicketInterface.sol";
import "../libraries/SharedFuncs.sol";

/**
 * @title Contract for a ticket
 */
contract Ticket is TicketInterface {

    SharedStructs.TicketData private ticketData;

    /**
     * @notice Creates an instance of the ticket contract
     * @param flightAddress - Address of the flight contract for which ticket is booked
     * @param buyer - Information of the buyer
     * @param numberOfSeats - Number of seats to be booked
     * @param amount - Amount paid for booking the ticket
     * @param ticketAgreementAddress - Address of the ticket agreement bound to the ticket instance
     */
    constructor(address flightAddress, uint16 ticketNumber, SharedStructs.Buyer memory buyer, uint16 numberOfSeats, uint256 amount, 
    address payable ticketAgreementAddress) payable {
        ticketData.flightAddress = flightAddress;
        ticketData.ticketNumber = ticketNumber;
        ticketData.buyer.name = buyer.name;
        ticketData.buyer.buyerAddress = buyer.buyerAddress;
        ticketData.numberOfSeats = numberOfSeats;
        ticketData.amount = amount;
        ticketData.ticketAgreementAddress = ticketAgreementAddress;
    }

    /**
     * @notice Cancels the ticket
     * @return Summary of the operation 
     */
    function cancel() external override payable returns (string memory) {
        string memory message;
        if (ticketData.status == SharedStructs.TicketStatuses.Open) {
            // Update the status and timestamp of the ticket, so that it will be available during account settlements.
            ticketData.cancelledDateTime = SharedFuncs.getCurrentDateTime();
            ticketData.status = SharedStructs.TicketStatuses.Cancelled;
            this.settleAccounts();
        }
        else {
            message = "Ticket is either settled or cancelled. Hence, cannot be cancelled";
        }
        return message;
    }
    
    /**
     * @notice Settles accounts associated with the ticket
     * @return Summary of the operation 
     */
    function settleAccounts() external override payable returns (string memory) {
        string memory message;

        if (ticketData.ticketAgreementAddress != address(0)) {
            (bool success,) = ticketData.ticketAgreementAddress.delegatecall(abi.encodeWithSignature("settleAccounts()"));
            if (success) {
                ticketData.status = SharedStructs.TicketStatuses.Settled;
                message = "Accounts settled successfully.";
            } else {
                message = "Error occured while settling the accounts.";
            }
        }

        return message;
    }

    /**
     * @notice Gets the status of the ticket
     * @return Status of the ticket
     */
    function getStatus() external override view returns (SharedStructs.TicketStatuses) {
        return ticketData.status;
    }
}