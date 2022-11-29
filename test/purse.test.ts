import "@nomiclabs/hardhat-ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract } from "ethers";
import hre, { ethers } from "hardhat";
//import { time } from "@nomicfoundation/hardhat-network-helpers";
//import {time} from "@openzeppelin/test-helpers";
import { timeTravel } from "./test-utils";
import {PurseFactory} from "../typechain";
import {PurseContract} from "../typechain";
import {Token} from "../typechain";



describe("Thrift", () => {
  
  let purseFactory: Contract;
  let token: Contract;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let non_member: SignerWithAddress

  before(async() => {
    [user1, user2, user3, non_member] = await ethers.getSigners();

    const purseFactoryArtifacts = await ethers.getContractFactory(
      "PurseFactory"
    );
    // deploy purseFactory
    purseFactory = await purseFactoryArtifacts.deploy();

    const tokenArtifacts = await ethers.getContractFactory("Token");

    // deploy token
    token = await tokenArtifacts.deploy();

  })

  describe(("purse: assuming all members donate as at when due"), async ()=> {

    
    let purse: Contract;
  

  before(async () => {
   

    const purseArtifacts = await ethers.getContractFactory("PurseContract");
    

    // user1 should approve purseFactory address
    await token.connect(user1).approve(purseFactory.address, (await ethers.utils.parseUnits("50","ether")).toString());

    //send tokens to user2 and 3 and non_member
    await token.connect(user1).transfer(user2.address, (await ethers.utils.parseUnits("100","ether")).toString());
    await token.connect(user1).transfer(user3.address, (await ethers.utils.parseUnits("100","ether")).toString());
    await token.connect(user1).transfer(non_member.address, (await ethers.utils.parseUnits("100","ether")).toString());


    const crp = await purseFactory
      .connect(user1)
      .createPurse((await ethers.utils.parseUnits("10","ether")).toString(), 3, 7, 1, token.address, 1);
    const crpEvent = ((await crp.wait()).events)[3].args;

      const purse_add = crpEvent.purseAddress;
     
    //const purse_address = purseAddress.toString();
  //  console.log(purseAddress.wait(), "purseAddress");

    purse = await purseArtifacts.attach(purse_add);
   

  });

  
  it("users can join a purse and should revert for an existing member", async()=> {

    await token.connect(user2).approve(purse.address, (await ethers.utils.parseUnits("50","ether")).toString());
    await token.connect(user3).approve(purse.address, (await ethers.utils.parseUnits("50","ether")).toString());

    await purse.connect(user2).joinPurse(2);
    await expect(purse.connect(user2).joinPurse(2)).to.be.revertedWith("you are already a member in this purse");
    await purse.connect(user3).joinPurse(3);

    const purse_members = await purse.purseMembers();




    expect(purse_members.includes(user1.address, 0)).to.equal(true);
    expect(purse_members.includes(user2.address, 0)).to.equal(true);
    expect(purse_members.includes(user3.address, 0)).to.equal(true);
    expect((await purse.purseMembers()).length).to.equal(3);
  
   
  });

  it("should revert if a new user attempts to join this purse after max number of members have joined", async()=> {
     await expect(purse.connect(non_member).joinPurse(3)).to.be.revertedWith("This purse is not longer accepting members");
  })

  

  it("should revert for a deposit for a user whose position is not yet time", async()=> [
    await expect(purse.connect(user1).depositDonation(user2.address)).to.be.revertedWith("not this members round")

  ])

  it("should deposit donation and emit appropriate event", async()=> {
    
    await expect(purse.connect(user2).depositDonation(user1.address)).to.emit(purse, "DonationDeposited").withArgs(user2.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user1.address);
    await expect(purse.connect(user3).depositDonation(user1.address)).to.emit(purse, "DonationDeposited").withArgs(user3.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user1.address);
  })

  it("first user should be able to claim donation", async() => {
    const userBalanceBeforeClaim:any = await ethers.utils.formatEther(await token.balanceOf(user1.address));

    console.log(userBalanceBeforeClaim, "b4")

   await purse.connect(user1).claimDonations()

    const newBalance:any = await ethers.utils.formatEther(await token.balanceOf(user1.address))
   
    

   await expect(newBalance - userBalanceBeforeClaim).to.equals(20)
    
  })

  it("should return correct round details and check for next round", async()=> {
    const roundDetails = await purse.currentRoundDetails();
    expect(roundDetails[0]).to.eq(user1.address);
    expect(roundDetails[1]).to.eq(1);
    console.log(roundDetails, "first round details");
    
   //increase timestamp by atleast 7days- this is 8days from now
   const next_thrift_period = '2022-12-07';

   const date = new Date(next_thrift_period);

   const next_timestamp = Math.floor(date.getTime() / 1000);

  
  // check timtstamp for next round
  expect(Number(roundDetails[2])).to.lessThan(Number(next_timestamp))

    await timeTravel(next_timestamp);

    
    //check that user2 owns current round at this time
    const second_roundDetails = await purse.currentRoundDetails();
    expect(second_roundDetails[0]).to.eq(user2.address);
    expect(second_roundDetails[1]).to.eq(2);
    

    console.log(second_roundDetails, "second round details")
   
  })

  it("should let the other users claim assume they all donate: for user2 and user3", async()=> {


      //for user2
    await token.connect(user1).approve(purse.address, (await ethers.utils.parseUnits("10","ether")).toString());
    await token.connect(user3).approve(purse.address, (await ethers.utils.parseUnits("10","ether")).toString());

    //user1 and user3 should donate for user2
    await expect(purse.connect(user1).depositDonation(user2.address)).to.emit(purse, "DonationDeposited").withArgs(user1.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user2.address);
    await expect(purse.connect(user3).depositDonation(user2.address)).to.emit(purse, "DonationDeposited").withArgs(user3.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user2.address);

    const user2BalanceBeforeClaim:any = await ethers.utils.formatEther(await token.balanceOf(user2.address));

   await purse.connect(user2).claimDonations()

    const newUser2Balance:any = await ethers.utils.formatEther(await token.balanceOf(user2.address))

    console.log(user2BalanceBeforeClaim, newUser2Balance);
   
  // expect his balance to have increased  by 20
   await expect(newUser2Balance - user2BalanceBeforeClaim).to.equals(20)


   //for user 3 
   // first shift timestamp

   //increase timestamp by atleast 7days- this is 8days from now
   const next_thrift_period = '2022-12-14';

   const date = new Date(next_thrift_period);

   const next_timestamp = Math.floor(date.getTime() / 1000);

    await timeTravel(next_timestamp);

    await token.connect(user1).approve(purse.address, (await ethers.utils.parseUnits("10","ether")).toString());
    await token.connect(user2).approve(purse.address, (await ethers.utils.parseUnits("10","ether")).toString());

    //user1 and user3 should donate for user2
    await expect(purse.connect(user1).depositDonation(user3.address)).to.emit(purse, "DonationDeposited").withArgs(user1.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user3.address);
    await expect(purse.connect(user2).depositDonation(user3.address)).to.emit(purse, "DonationDeposited").withArgs(user2.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user3.address);

    const user3BalanceBeforeClaim:any = await ethers.utils.formatEther(await token.balanceOf(user3.address));

   await purse.connect(user3).claimDonations()

    const newUser3Balance:any = await ethers.utils.formatEther(await token.balanceOf(user3.address))

    console.log(user3BalanceBeforeClaim, newUser3Balance);
   
  // expect his balance to have increased  by 20
   await expect(newUser3Balance - user3BalanceBeforeClaim).to.equals(20)

  })
})

  describe("For instances of missed donations", async() => {
    let purse: Contract;
  

    before(async () => {
     
  
      const purseArtifacts = await ethers.getContractFactory("PurseContract");
      
  
      // user1 should approve purseFactory address
      await token.connect(user1).approve(purseFactory.address, (await ethers.utils.parseUnits("50","ether")).toString());
  
      //send tokens to user2 and 3 and non_member
      await token.connect(user1).transfer(user2.address, (await ethers.utils.parseUnits("100","ether")).toString());
      await token.connect(user1).transfer(user3.address, (await ethers.utils.parseUnits("100","ether")).toString());
      await token.connect(user1).transfer(non_member.address, (await ethers.utils.parseUnits("100","ether")).toString());
  
  
      const crp = await purseFactory
        .connect(user1)
        .createPurse((await ethers.utils.parseUnits("10","ether")).toString(), 3, 7, 1, token.address, 1);
      const crpEvent = ((await crp.wait()).events)[3].args;
  
        const purse_add = crpEvent.purseAddress;
       
      //const purse_address = purseAddress.toString();
    //  console.log(purseAddress.wait(), "purseAddress");
  
      purse = await purseArtifacts.attach(purse_add);
     
  
    });

    it("should calculate missed Donations", async()=> {
        // for user2 and 3 should join purse
        await token.connect(user2).approve(purse.address, (await ethers.utils.parseUnits("100","ether")).toString());
        await token.connect(user3).approve(purse.address, (await ethers.utils.parseUnits("100","ether")).toString());
        await token.connect(user1).approve(purse.address, (await ethers.utils.parseUnits("100","ether")).toString());

        await purse.connect(user2).joinPurse(2);
        await purse.connect(user3).joinPurse(3);

        // both user2 and 3 deposit for user1

        await expect(purse.connect(user2).depositDonation(user1.address)).to.emit(purse, "DonationDeposited").withArgs(user2.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user1.address);
        await expect(purse.connect(user3).depositDonation(user1.address)).to.emit(purse, "DonationDeposited").withArgs(user3.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user1.address);
     

      // user1 shuuld be able t claimn
      await purse.connect(user1).claimDonations();


       //increase timestamp by atleast 7days- this is 8days from now to allow for new donation
   const next_thrift_period = '2022-12-23';

   const date = new Date(next_thrift_period);

   const next_timestamp = Math.floor(date.getTime() / 1000);

    await timeTravel(next_timestamp);

    // user3 should miss for user2, only user1 should deposit
    await expect(purse.connect(user1).depositDonation(user2.address)).to.emit(purse, "DonationDeposited").withArgs(user1.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user2.address);


    // for user3- only user2 should donate for user3
    // increase time


       //increase timestamp by atleast 7days- this is 8days from now to allow for new donation
   const next_thrift_period_2 = '2022-12-31';

   const date_2 = new Date(next_thrift_period_2);

   const next_timestamp_2 = Math.floor(date_2.getTime() / 1000);

    await timeTravel(next_timestamp_2);

    // user2 freom previous round should be able to claim deonation
    await purse.connect(user2).approveToClaimWithoutCompleteVotes(user2.address);
    await purse.connect(user2).claimDonations();

    await expect(purse.connect(user2).depositDonation(user3.address)).to.emit(purse, "DonationDeposited").withArgs(user2.address, (await ethers.utils.parseUnits("10","ether")).toString(), purse.address, user3.address);


       //increase timestamp by atleast 7days-
   const next_thrift_period_3 = '2023-01-09';

   const date_3 = new Date(next_thrift_period_3);

   const next_timestamp_3 = Math.floor(date_3.getTime() / 1000);

    await timeTravel(next_timestamp_3);

    // calculate missed donations for user2 and check that only user3 missed donation for it
    const missed_donation_for_user2 = await purse.calculateMissedDonationForUser(user2.address);

    //assert that only user3 missed donation for user2
    expect(missed_donation_for_user2[0][0]).to.eq(user3.address);
    expect(missed_donation_for_user2[0].length).to.eq(1); 
    expect(missed_donation_for_user2[1].toString()).to.eq(await ethers.utils.parseUnits("10","ether")).toString();

    //calculate missed donation by user2
    const missed_donation_by_user2 = await purse.calculateMissedDonationByUser(user2.address);
    console.log(missed_donation_by_user2, "missed donation by user2");

    //assert that user2 didnt donate for only user3
    expect(missed_donation_by_user2[0][0]).to.eq(user3.address);
    expect(missed_donation_by_user2[0].length).to.eq(1); 
    expect(missed_donation_by_user2[1].toString()).to.eq(await ethers.utils.parseUnits("10","ether")).toString();


  

    })

  })

  
});
