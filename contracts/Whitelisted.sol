// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

library Whitelist {
  
  struct List {
    mapping(address => uint8) registry;
  }
  
  function add(List storage list, address _addr, uint8 _degree)
    internal
  {
    require(list.registry[_addr] + _degree < 4);
    list.registry[_addr] = _degree;
  }

  function sub(List storage list, address _addr, uint8 _degree)
    internal
  {
    require( list.registry[_addr] > 0 );
    require( list.registry[_addr] >= _degree );
    list.registry[_addr] -= _degree;
  }

  function check(List storage list, address _addr)
    view
    internal
    returns (uint8)
  {
    return list.registry[_addr];
  }
}