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
 
  
  const _2_days_time = +new Date(Date.UTC(2022, 6, 26, 0, 0, 0)) / 1000;


  before(async () => {
    [user1, user2, user3] = await ethers.getSigners();

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
    await token.connect(user1).approve(purseFactory.address, 50);

    //send tokens to user2 and 3
    await token.connect(user1).transfer(user2.address, 100);
    await token.connect(user1).transfer(user3.address, 100);

   const crp = await purseFactory
      .connect(user1)
      .createPurse(10, 3, 7, 1, token.address, 1);
const crpEvent = ((await crp.wait()).events)[3].args;
      const purse_add = crpEvent.purseAddress;
     
    //const purse_address = purseAddress.toString();
  //  console.log(purseAddress.wait(), "purseAddress");

    purse = await purseArtifacts.attach(purse_add);
    console.log(purse, "purse");

  });


  describe(("purse functionalities"), async()=> {

  
  it("users can join a purse", async()=> {

    await token.connect(user2).approve(purse.address, 50);
    await token.connect(user3).approve(purse.address, 50);

    await purse.connect(user2).joinPurse(2);
    await purse.connect(user3).joinPurse(3);



    expect((await purse.purseMembers()).length).to.equal(3);
    

    
   // await timeTravel(_2_days_time);
    // calculate currentRoundDetails

    const roundDetails = await purse.currentRoundDetails();

    console.log(roundDetails.toString(), "round details");
   
  })
})

  
});
