-module(etorrent_pieceset_tests).

-include_lib("eunit/include/eunit.hrl").

-undef(LET).
-define(PROPER_NO_IMPORTS, true).
-include_lib("proper/include/proper.hrl").
-define(set, etorrent_pieceset).

%% The highest bit in the first byte corresponds to piece 0.
high_bit_test() ->
    Set = ?set:from_binary(<<1:1, 0:7>>, 8),
    ?assert(?set:is_member(0, Set)).

%% And the bit after that corresponds to piece 1.
bit_order_test() ->
    Set = ?set:from_binary(<<1:1, 1:1, 0:6>>, 8),
    ?assert(?set:is_member(0, Set)),
    ?assert(?set:is_member(1, Set)).

%% The lowest bit in the first byte corresponds to piece 7,
%% and the highest bit in the second byte corresponds to piece 8.
byte_boundry_test() ->
    Set = ?set:from_binary(<<0:7, 1:1, 1:1, 0:7>>, 16),
    ?assert(?set:is_member(7, Set)),
    ?assert(?set:is_member(8, Set)).

%% The remaining bits should be padded with zero and ignored
padding_test() ->
    Set = ?set:from_binary(<<0:8, 0:6, 1:1, 0:1>>, 15),
    ?assert(?set:is_member(14, Set)),
    ?assertError(badarg, ?set:is_member(15, Set)).

%% If the padding is invalid, the conversion from
%% bitfield to pieceset should crash.
invalid_padding_test() ->
    ?assertError(badarg, ?set:from_binary(<<0:7, 1:1>>, 7)).

%% Piece indexes can never be less than zero
negative_index_test() ->
    ?assertError(badarg, ?set:is_member(-1, undefined)).

%% Piece indexes that fall outside of the index range should fail
too_high_member_test() ->
    Set = ?set:new(8),
    ?assertError(badarg, ?set:is_member(8, Set)).

%% An empty piece set should contain 0 pieces
empty_size_test() ->
    ?assertEqual(0, ?set:size(?set:new(8))),
    ?assertEqual(0, ?set:size(?set:new(14))).

full_size_test() ->
    Set0 = ?set:from_binary(<<255:8>>, 8),
    ?assertEqual(8, ?set:size(Set0)),
    Set1 = ?set:from_binary(<<255:8, 1:1, 0:7>>, 9),
    ?assertEqual(9, ?set:size(Set1)).

%% An empty set should be converted to an empty list
empty_list_test() ->
    Set = ?set:new(8),
    ?assertEqual([], ?set:to_list(Set)).

%% Expect the list to be ordered from smallest to largest
list_order_test() ->
    Set = ?set:from_binary(<<1:1, 0:7, 1:1, 0:7>>, 9),
    ?assertEqual([0,8], ?set:to_list(Set)).

%% Expect an empty list to be converted to an empty set
from_empty_list_test() ->
    Set0 = ?set:new(8),
    Set1 = ?set:from_list([], 8),
    ?assertEqual(Set0, Set1).

from_full_list_test() ->
    Set0 = ?set:from_binary(<<255:8>>, 8),
    Set1 = ?set:from_list(lists:seq(0,7), 8),
    ?assertEqual(Set0, Set1).

min_test_() ->
    [?_assertError(badarg, ?set:min(?set:new(20))),
     ?_assertEqual(0, ?set:min(?set:from_list([0], 8))),
     ?_assertEqual(1, ?set:min(?set:from_list([1,7], 8))),
     ?_assertEqual(15, ?set:min(?set:from_list([15], 16)))].

first_test_() ->
    Set = ?set:from_list([0,1,2,4,8,16,17], 18),
    [?_assertEqual(0, ?set:first([0,1], Set)),
     ?_assertEqual(1, ?set:first([1,0], Set)),
     ?_assertEqual(17, ?set:first([17,0,1], Set)),
     ?_assertError(badarg, ?set:first([9,15], Set))].

%%
%% Modifying the contents of a pieceset
%%

%% Piece indexes can never be less than zero.
negative_index_insert_test() ->
    ?assertError(badarg, ?set:insert(-1, undefined)).

%% Piece indexes should be within the range of the piece set
too_high_index_test() ->
    Set = ?set:new(8),
    ?assertError(badarg, ?set:insert(8, Set)).

%% The index of the last piece should work though
max_index_test() ->
    Set = ?set:new(8),
    ?assertMatch(_, ?set:insert(7, Set)).

%% Inserting a piece into a piece set should make it a member of the set
insert_min_test() ->
    Init = ?set:new(8),
    Set  = ?set:insert(0, Init),
    ?assert(?set:is_member(0, Set)),
    ?assertEqual(<<1:1, 0:7>>, ?set:to_binary(Set)).

insert_max_min_test() ->
    Init = ?set:new(5),
    Set  = ?set:insert(0, ?set:insert(4, Init)),
    ?assert(?set:is_member(4, Set)),
    ?assert(?set:is_member(0, Set)),
    ?assertEqual(<<1:1, 0:3, 1:1, 0:3>>, ?set:to_binary(Set)).

delete_invalid_index_test() ->
    Set = ?set:new(3),
    ?assertError(badarg, ?set:delete(-1, Set)),
    ?assertError(badarg, ?set:delete(3, Set)).

delete_test() ->
    Set = ?set:from_list([0,2], 3),
    ?assertNot(?set:is_member(0, ?set:delete(0, Set))),
    ?assertNot(?set:is_member(2, ?set:delete(2, Set))).

intersection_size_test() ->
    Set0 = ?set:new(5),
    Set1 = ?set:new(6),
    ?assertError(badarg, ?set:intersection(Set0, Set1)).

intersection_test() ->
    Set0  = ?set:from_binary(<<1:1, 0:7,      1:1, 0:7>>, 16),
    Set1  = ?set:from_binary(<<1:1, 1:1, 0:6, 1:1, 0:7>>, 16),
    Inter = ?set:intersection(Set0, Set1),
    Bitfield = <<1:1, 0:1, 0:6, 1:1, 0:7>>,
    ?assertEqual(Bitfield, ?set:to_binary(Inter)).

difference_size_test() ->
    Set0 = ?set:new(5),
    Set1 = ?set:new(6),
    ?assertError(badarg, ?set:difference(Set0, Set1)).

difference_test() ->
    Set0  = ?set:from_list([0,1,    4,5,6,7], 8),
    Set1  = ?set:from_list([  1,2,3,4,  6,7], 8),
    Inter = ?set:difference(Set0, Set1),
    ?assertEqual([0,5], ?set:to_list(Inter)).

%%
%% Conversion from piecesets to bitfields should produce valid bitfields.
%%

%% Starting from bit 0.
piece_0_test() ->
    Bitfield = <<1:1, 0:7>>,
    Set = ?set:from_binary(Bitfield, 8),
    ?assertEqual(Bitfield, ?set:to_binary(Set)).

%% Continuing into the second byte with piece 8.
piece_8_test() ->
    Bitfield = <<1:1, 0:7, 1:1, 0:7>>,
    Set = ?set:from_binary(Bitfield, 16),
    ?assertEqual(Bitfield, ?set:to_binary(Set)).

%% Preserving the original padding of the bitfield.
pad_binary_test() ->
    Bitfield = <<1:1, 1:1, 1:1, 0:5>>,
    Set = ?set:from_binary(Bitfield, 4),
    ?assertEqual(Bitfield, ?set:to_binary(Set)).

%% An empty pieceset should include the number of pieces
empty_pieceset_string_test() ->
    ?assertEqual("<pieceset(8) []>", ?set:to_string(?set:empty(8))).

one_element_pieceset_string_test() ->
    ?assertEqual("<pieceset(8) [0]>", ?set:to_string(?set:from_list([0], 8))).

two_element_0_pieceset_string_test() ->
    ?assertEqual("<pieceset(8) [0,2]>", ?set:to_string(?set:from_list([0,2], 8))).

two_element_1_pieceset_string_test() ->
    ?assertEqual("<pieceset(16) [0,15]>", ?set:to_string(?set:from_list([0,15], 16))).

three_element_pieceset_string_test() ->
    ?assertEqual("<pieceset(8) [0,2,7]>", ?set:to_string(?set:from_list([0,2,7], 8))).

two_element_range_string_test() ->
    ?assertEqual("<pieceset(8) [0-1]>", ?set:to_string(?set:from_list([0,1], 8))).

three_element_range_string_test() ->
    ?assertEqual("<pieceset(8) [0-2]>", ?set:to_string(?set:from_list([0,1,2], 8))).

ranges_string_test() ->
    ?assertEqual("<pieceset(8) [0,2-3,5-7]>", ?set:to_string(?set:from_list([0,2,3,5,6,7], 8))).



-ifdef(PROPER).
prop_min() ->
    ?FORALL({Elem, Size},
    ?SUCHTHAT({E, S}, {non_neg_integer(), pos_integer()}, E < S),
    begin
        Elem == ?set:min(?set:from_list([Elem], Size))
    end).

prop_full() ->
    ?FORALL(Size, pos_integer(),
    begin
        All = lists:seq(0, Size - 1),
        Set = ?set:from_list(All, Size),
        ?set:is_full(Set)
    end).

prop_not_full() ->
    ?FORALL({Elem, Size},
    ?SUCHTHAT({E, S}, {non_neg_integer(), pos_integer()}, E < S),
    begin
        All = lists:seq(0, Size - 1),
        Not = lists:delete(Elem, All),
        Set = ?set:from_list(Not, Size),
        not ?set:is_full(Set)
    end).

prop_min_test() ->
    ?assertEqual(true, proper:quickcheck(prop_min())).

prop_full_test() ->
    ?assertEqual(true, proper:quickcheck(prop_full())).

prop_not_full_test() ->
    ?assertEqual(true, proper:quickcheck(prop_not_full())).

-endif.
