pragma solidity ^0.5.15;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

contract GarbledCircuit {
    using SafeMath for uint256;

    struct GarbledTruthTable {
        uint256 parent_table_index;
        bool is_input_x;
        mapping(uint256 => bytes32) entry;
        bytes32 input_x;
        bytes32 input_y;
    }

    uint256 public num_inputs;
    uint256 public num_tables;
    uint256 public num_results;
    mapping(uint256 => uint256) decrpytion_result;
    mapping(uint256 => GarbledTruthTable) circuit;
    mapping(uint256 => BitResult) outputs;

    struct BitResult {
        bytes32 bit_zero;
        bytes32 bit_one;
    }

    function read_gtt(uint256 table_index) public view returns(bytes32[4] memory gtt) {
        gtt[0] = circuit[table_index].entry[0];
        gtt[1] = circuit[table_index].entry[1];
        gtt[2] = circuit[table_index].entry[2];
        gtt[3] = circuit[table_index].entry[3];
    }

    function read_inputs_of_table(uint256 table_index) public view returns(bytes32[2] memory inputs) {
        inputs[0] = circuit[table_index].input_x;
        inputs[1] = circuit[table_index].input_y;
    }

    function read_outputs_of_table(uint256 table_index) public view returns(bytes32[2] memory _outputs) {
        _outputs[0] = outputs[table_index].bit_zero;
        _outputs[1] = outputs[table_index].bit_one;
    }

    function read_decryption_result(uint256 table_index) public view returns(uint256) {
        // 2: true
        // 1: false
        // 0: not set
        require(decrpytion_result[table_index] > 0, "Decryption result is not set");
        return decrpytion_result[table_index] - 1;
    }

    function decrypt(
        uint256[] memory table_index_of_garbled_inputs,
        bytes32[] memory garbled_inputs,
        uint256[2][] memory entries_chosen,
        uint256[] memory table_index_of_end_tables) public {
        require(garbled_inputs.length == num_inputs, "Mismatched number of garbled inputs.");
        require(table_index_of_garbled_inputs.length == garbled_inputs.length, "Mismatch between number of table indices and number of garbled inputs");
        require(entries_chosen.length == num_tables, "Mismatched number of chosen entries(should match the number of tables).");
        require(table_index_of_end_tables.length == num_results, "Mismatched number of end tables.");

        // Fill in the given inputs
        for(uint256 i = 0; i < num_inputs; i++) {
            circuit[table_index_of_garbled_inputs[i]].input_x = garbled_inputs[i];
        }

        uint256 table_index;
        bytes32 entry;
        uint256 result;
        bool is_end_table;
        for(uint256 i = 0; i < entries_chosen.length; i++) {
            table_index = entries_chosen[i][0];
            entry = circuit[table_index].entry[entries_chosen[i][1]];
            result = uint256(entry) ^ uint256(circuit[table_index].input_x) ^ uint256(circuit[table_index].input_y);
            is_end_table = false;
            for(uint256 j = 0; j < table_index_of_end_tables.length; j++) {
                if(table_index == table_index_of_end_tables[j]) {
                    is_end_table = true;
                }
            }
            if(is_end_table == true) {
                if(result == uint256(outputs[table_index].bit_zero)) {
                    decrpytion_result[i] = 1;
                } else if(result == uint256(outputs[table_index].bit_one)) {
                    decrpytion_result[i] = 2;
                } else {
                    revert("Incorrect result.");
                }
            } else {
                if(circuit[table_index].is_input_x == true) {
                    circuit[circuit[table_index].parent_table_index].input_x = bytes32(result);
                } else {
                    circuit[circuit[table_index].parent_table_index].input_y = bytes32(result);
                }
            }
        }
    }

    function deploy(
        uint256 _num_inputs,
        uint256[3][] memory table_relation,
        bytes32[4][] memory all_table_entries,
        uint256[] memory table_index_of_garbled_inputs,
        bytes32[] memory garbled_inputs,
        uint256[] memory table_index_of_outputs,
        bytes32[2][] memory _outputs) public {
        require(_num_inputs > 0, "Invalid number of bits for the circuit.");
        require(garbled_inputs.length == _num_inputs, "Mismatched number of inputs.");
        require(table_index_of_garbled_inputs.length == garbled_inputs.length, "Mismatch between number of table indices and number of garbled inputs");
        require(all_table_entries.length > _num_inputs, "Number of tables should be greater than number of inputs.");
        num_inputs = _num_inputs;
        num_tables = all_table_entries.length;

        uint256 table_index;
        for(uint256 i = 0; i < garbled_inputs.length; i++) {
            table_index = table_index_of_garbled_inputs[i];
            circuit[table_index].input_y = garbled_inputs[i];
        }
        for(uint256 i = 0; i < table_relation.length; i++) {
            circuit[table_relation[i][0]].parent_table_index = table_relation[i][1];
            if(table_relation[i][2] == 1) {
                circuit[table_relation[i][0]].is_input_x = true;
            } else {
                circuit[table_relation[i][0]].is_input_x = false;
            }
        }
        for(uint256 i = 0; i < all_table_entries.length; i++) {
            circuit[i].entry[0] = all_table_entries[i][0];
            circuit[i].entry[1] = all_table_entries[i][1];
            circuit[i].entry[2] = all_table_entries[i][2];
            circuit[i].entry[3] = all_table_entries[i][3];
        }
        num_results = table_index_of_outputs.length;
        for(uint256 i = 0; i < table_index_of_outputs.length; i++) {
            table_index = table_index_of_outputs[i];
            outputs[table_index].bit_zero = _outputs[i][0];
            outputs[table_index].bit_one = _outputs[i][1];
        }
    }
}
