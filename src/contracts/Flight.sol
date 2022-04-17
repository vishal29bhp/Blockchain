// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.6 < 0.9.0;

import {Ticket} from "./Ticket.sol";
import "../interfaces/FlightInterface.sol";
import "../libraries/SharedConstants.sol";
import "../libraries/SharedFuncs.sol";

/**
 * @title Contract for a flight
 * @notice Contains members that are provided by a flight contract
 */
contract Flight is FlightInterface {

    SharedStructs.FlightDetails private flightDetails;
    uint16 private availableCapacity;
    uint16 private nextTicketNumber;
    uint256 private amountPerSeat;
    Ticket[] private tickets;

    /**
    * @notice Create and instance of flight contract
    * @param flightNumber - Flight number
    * @param originalDepartureDateTime - Original departure date time of the flight
    * @param seatingCapacity - Seating capacity of the flight
    * @param perSeatCharge - Charge per seat
    */
    constructor(string memory flightNumber, uint256 originalDepartureDateTime, uint16 seatingCapacity, uint256 perSeatCharge) payable {
        flightDetails.flightNumber = flightNumber;
        flightDetails.originalDepartureDateTime = originalDepartureDateTime;
        flightDetails.actualDepartureDateTime = originalDepartureDateTime;
        flightDetails.status = SharedStructs.FlightStatuses.OnTime;
        availableCapacity = seatingCapacity;
        nextTicketNumber = 0;
        amountPerSeat = perSeatCharge;
    }

    /**
    * @notice Books the ticket for the flight
    * @param buyer - Buyer information
    * @param numberOfSeatsRequired - Number of seats to be booked
    * @param ticketAgreementAddress - Address of the ticket agreement contract bound to the ticket
    * @return Ticket number
    * @return Ticket address
    * @return Message giving the summary the execution
    */
    function bookTicket(SharedStructs.Buyer calldata buyer, uint16 numberOfSeatsRequired, address payable ticketAgreementAddress) external override payable 
    returns (uint16, address, string memory) {
        
        string memory message;
        uint16 ticketNumber;
        address payable ticketAddress = payable(address(0));

        if (flightDetails.status != SharedStructs.FlightStatuses.OnTime && flightDetails.status != SharedStructs.FlightStatuses.Delayed) {
            message = "Booking for this flight is not allowed as it is either departed or cancelled.";
        } else if (numberOfSeatsRequired > availableCapacity) {
            message = "No seats available";
        } else {

            uint256 billedAmount = numberOfSeatsRequired * amountPerSeat;
            
            // Check balance of buyer's wallet. If insufficient then raise error otherwise deduct from buyer's wallet.
            require(buyer.buyerAddress.balance >= billedAmount, "Insufficient balance in buyer's account");

            Ticket ticket = new Ticket(address(this), ++nextTicketNumber, buyer, numberOfSeatsRequired, billedAmount, ticketAgreementAddress);
            // TODO: The below line is not working. Fix the issue.
            payable(address(ticket)).transfer(billedAmount);
            //payable(address(SharedConstants.ESCROW_SERVICE_ACCOUNT)).transfer(billedAmount);
            tickets.push(ticket);
            ticketNumber = nextTicketNumber;
            ticketAddress = payable(address(ticket));
            message = "Ticket booked successfully";
            availableCapacity -= numberOfSeatsRequired;

        }

        return (ticketNumber, ticketAddress, message);
    }

    /**
    * @notice Cancels the ticket for the flight
    * @return Total number of tickets cancelled
    * @return Message giving the summary the execution
    */
    function cancel() external override returns (uint16, string memory) {

        uint16 numberOfTickets;
        string memory message;

        if (flightDetails.status == SharedStructs.FlightStatuses.InTransit || flightDetails.status == SharedStructs.FlightStatuses.Completed) { 
            message = "Flight is either in transit or completed. Hence cannot be cancelled";
            numberOfTickets = 0;
        } else {
            // Update flight status first so that it will be reflected in the processing.
            flightDetails.status = SharedStructs.FlightStatuses.Cancelled;

            for(uint index = 0; index < tickets.length; index++) {
                tickets[index].settleAccounts();
            }
            numberOfTickets = uint16(tickets.length);
            message = "Flight is cancelled and tickets are settled successfully";
        }

        return (numberOfTickets, message);
    }

    /**
    * @notice Updates the depature time of the flight
    * @param newDepartureDateTime - New departure date time of the flight
    * @return Status of the flight depending on the new departure date time
    * @return Message giving the summary the execution
    */
    function updateDeparture(uint256 newDepartureDateTime) external override returns (SharedStructs.FlightStatuses, string memory) {

        string memory message;

        if (flightDetails.status != SharedStructs.FlightStatuses.OnTime && flightDetails.status != SharedStructs.FlightStatuses.Delayed) {
            message = "Departure update for this flight is not allowed as it is either departed or cancelled";
        } else {
            flightDetails.actualDepartureDateTime = newDepartureDateTime;

            // Check the new departure time. Depending on that update the flight status.
            if (newDepartureDateTime >= SharedFuncs.getCurrentDateTime())
            {
                flightDetails.status = SharedStructs.FlightStatuses.InTransit;
            } else if (flightDetails.originalDepartureDateTime < newDepartureDateTime) {
                flightDetails.status = SharedStructs.FlightStatuses.Delayed;
            } else {
                flightDetails.status = SharedStructs.FlightStatuses.OnTime;
                message = "Flight is updated successfully";
            }
        }
        return (flightDetails.status, message);
    }

    /**
    * @notice Marks the flight as complete
    * @return Number of tickets settled
    * @return Message giving the summary the execution
    */
    function complete() external override returns (uint16, string memory) {

        uint16 numberOfTickets;
        string memory message;

        if (flightDetails.status != SharedStructs.FlightStatuses.InTransit) {
            message =  "Flight must be in transit before completing it";
            numberOfTickets = 0;
        } else {
            // Update flight status first so that it will be reflected in the processing.
            flightDetails.status = SharedStructs.FlightStatuses.Completed;

            Ticket ticket;

            for(uint index = 0; index < tickets.length; index++) {
                ticket = tickets[index];
                if (ticket.getStatus() == SharedStructs.TicketStatuses.Open)
                {
                    // Settle only open ticket.
                    tickets[index].settleAccounts();
                }
            }
            message =  "Flight status is updated and tickets are settled";
            numberOfTickets = uint16(tickets.length);
        }

        return (numberOfTickets, message);
    }

    /**
    * @notice Gets the flight status
    * @return Status of the flight
    * @return New or actual departure date time
    */
    function getStatus() external override view returns (SharedStructs.FlightStatuses, uint256) {
        return (flightDetails.status, flightDetails.actualDepartureDateTime);
    }
}