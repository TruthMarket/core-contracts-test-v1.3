// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// 
interface Error {
    // 
    error NotAdmin(); 
    error NotAdminOrDAO(); 
    error ZeroAddress(); 
    error InvalidImplementation(); 

    error Blacklisted(); 
    //
    error InvalidCaller();
    error InvalidContractCaller();
    error InvalidStatus(); // 

    // 
    error NotOwner(); // 
    error NotMinter(); // 
    error NotBuyer(); // 
    error NotSeller(); //
}


