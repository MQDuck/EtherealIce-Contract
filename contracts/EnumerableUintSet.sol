//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

library EnumerableUintSet {
    struct Set {
        uint[] values;
        mapping (uint => uint) valueIdx;
    }

    function add(Set storage set, uint value) public {
        require(set.valueIdx[value] == 0, "EnumerableUintSet error: value already in set");
        set.values.push(value);
        set.valueIdx[value] = set.values.length;
    }

    function remove(Set storage set, uint value) public {
        require(set.valueIdx[value] != 0, "EnumerableUintSet error: value not in set");
        set.values[set.valueIdx[value] - 1] = set.values[set.values.length - 1];
        set.valueIdx[set.values[set.values.length - 1]] = set.valueIdx[value];
        set.valueIdx[value] = 0;
        delete set.values[set.values.length - 1];
    }
}
