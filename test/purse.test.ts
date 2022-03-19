import "@nomiclabs/hardhat-ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import chalk from "chalk";
import hre, { ethers } from "hardhat";
import { Contract } from "ethers";


describe("purse and purse factory functionalities", ()=> {

    let user1: SignerWithAddress
    let user2: SignerWithAddress
    let testToken: Contract
    let purseFactory: Contract

    beforeEach( async()=> {
        //get addresses for defined users user1 and 2
        [user1, user2] = await ethers.getSigners();
        console.log(user2.address, 'second user')
        
        // deploy token as the address is needed in purseFactory deployment
        const tokenFactory = await ethers.getContractFactory("Token");
        testToken = await tokenFactory.attach("0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735");


        console.log(await ethers.utils.formatEther((await testToken.balanceOf(user1.address)).toString()), "balanceOf of User1")

        console.log(testToken.address, "address of token");

        const purseFactoryFactory = await ethers.getContractFactory("PurseFactory");
        purseFactory = await purseFactoryFactory.deploy();

        console.log(purseFactory.address, "purse factory")
    })

    it("should create a purse", async()=> {
        console.log("approving contract to spend token");
        const approveTx= await (await testToken.connect(user1).approve(purseFactory.address, 40)).wait();
        console.log(approveTx, "approve tx");
         console.log("creating a purse")
        mineNext()
         
        const purse = await purseFactory.connect(user1).createPurse(20, 40, 3, 3, 1);
        console.log(await purse.wait(), "deployed purse")
    

    })

    
})