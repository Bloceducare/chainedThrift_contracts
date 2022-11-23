import "@nomiclabs/hardhat-ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";
import { timeTravel } from "./test-utils";
import {PurseFactory} from "../typechain";
import {PurseContract} from "../typechain";
import {Token} from "../typechain";


describe("Thrift", () => {
  let purseFactory: Contract;
  let purse: Contract;
  let token: Contract;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let non_member: SignerWithAddress
 
  
  const _2_days_time = +new Date(Date.UTC(2022, 6, 26, 0, 0, 0)) / 1000;


  before(async () => {
    [user1, user2, user3, non_member] = await ethers.getSigners();

    const purseFactoryArtifacts = await ethers.getContractFactory(
      "PurseFactory"
    );
    const purseArtifacts = await ethers.getContractFactory("PurseContract");
    const tokenArtifacts = await ethers.getContractFactory("Token");

    // deploy purseFactory
    purseFactory = await purseFactoryArtifacts.deploy();

    // deploy token
    token = await tokenArtifacts.deploy();

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


  describe(("purse functionalities"), ()=> {

  
  it("users can join a purse", async()=> {

    await token.connect(user2).approve(purse.address, (await ethers.utils.parseUnits("50","ether")).toString());
    await token.connect(user3).approve(purse.address, (await ethers.utils.parseUnits("50","ether")).toString());

    await purse.connect(user2).joinPurse(2);
    await purse.connect(user3).joinPurse(3);

    const purse_members = await purse.purseMembers();




    expect(purse_members.includes(user1.address, 0)).to.equal(true);
    expect(purse_members.includes(user2.address, 0)).to.equal(true);
    expect(purse_members.includes(user3.address, 0)).to.equal(true);
    expect((await purse.purseMembers()).length).to.equal(3);
    

    
   // await timeTravel(_2_days_time);
    // calculate currentRoundDetails

    const roundDetails = await purse.currentRoundDetails();

    console.log(roundDetails, "round details");
   
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
})

  
});
