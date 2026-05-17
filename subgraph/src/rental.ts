import { BigInt } from "@graphprotocol/graph-ts";
import {
  ItemListed,
  ItemRented,
  ItemReclaimed,
} from "../../generated/RentalVault/RentalVault";
import { Listing, RentalEvent } from "../../generated/schema";

export function handleItemListed(event: ItemListed): void {
  let id = event.params.listingId.toString();
  let listing = new Listing(id);
  listing.lender = event.params.lender;
  listing.itemId = event.params.itemId;
  listing.amount = event.params.amount;
  listing.pricePerPeriod = event.params.pricePerPeriod;
  listing.active = true;
  listing.save();
}

export function handleItemRented(event: ItemRented): void {
  let id = event.params.listingId.toString();
  let listing = Listing.load(id);
  if (listing == null) return;

  listing.renter = event.params.renter;
  listing.rentalEnd = event.params.rentalEnd;
  listing.save();

  let rentId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let rental = new RentalEvent(rentId);
  rental.listing = id;
  rental.renter = event.params.renter;
  rental.rentalEnd = event.params.rentalEnd;
  rental.feePaid = event.params.feePaid;
  rental.timestamp = event.block.timestamp;
  rental.blockNumber = event.block.number;
  rental.save();
}

export function handleItemReclaimed(event: ItemReclaimed): void {
  let id = event.params.listingId.toString();
  let listing = Listing.load(id);
  if (listing == null) return;
  listing.active = false;
  listing.renter = null;
  listing.rentalEnd = null;
  listing.save();
}
