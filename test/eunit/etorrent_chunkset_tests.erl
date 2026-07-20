-module(etorrent_chunkset_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_chunkset, [subtract/3]).

-define(set, etorrent_chunkset).

new_test() ->
    Set = ?set:new(32, 2),
    ?assertEqual(32, ?set:size(Set)),
    ?assertEqual(?set:from_list(32, 2, [{0, 31}]), Set).

new_min_test() ->
    ?assertEqual({0, 2}, ?set:min(?set:new(32, 2))),
    ?assertEqual({0, 3}, ?set:min(?set:new(32, 3))).

min_smaller_test() ->
    Set = ?set:from_list(32, 4, [{0,1},{3, 31}]),
    ?assertEqual({0,2}, ?set:min(Set)).

min_empty_test() ->
    Set = ?set:from_list(32, 2, []),
    ?assertError(badarg, ?set:min(Set)).

min_zero_test() ->
    Set = ?set:from_list(2, 1, [{0,0}]),
    ?assertEqual({0,1}, ?set:min(Set)).

is_empty_test() ->
    Set = ?set:from_list(2, 1, []),
    ?assert(?set:is_empty(Set)).

not_is_empty_test() ->
    Set = ?set:from_list(2, 1, [{0,0}]),
    ?assertNot(?set:is_empty(Set)).

delete_invalid_length_test() ->
    ?assertError(badarg, ?set:delete(0, 0, ?set:new(32, 2))),
    ?assertError(badarg, ?set:delete(0, -1, ?set:new(32, 2))).

delete_invalid_offset_test() ->
    ?assertError(badarg, ?set:delete(-1, 1, ?set:new(32, 2))).

delete_empty_test() ->
    Set = ?set:from_list(32, 2, []),
    ?assertEqual(Set, ?set:delete(0, 1, Set)).

delete_head_test() ->
    Set0 = ?set:new(32, 2),
    Set1 = ?set:delete(0, 2, Set0),
    Set2 = ?set:delete(0, 3, Set1),
    ?assertEqual(?set:from_list(32, 2, [{2,31}]), Set1),
    ?assertEqual(?set:from_list(32, 2, [{3,31}]), Set2).

delete_head_size_test() ->
    Set = ?set:delete(0, 2, ?set:new(32, 2)),
    ?assertEqual(30, ?set:size(Set)).
    
delete_middle_test() ->
    Set0 = ?set:new(32, 2),
    Set1 = ?set:delete(2, 2, Set0),
    ?assertEqual(30, ?set:size(Set1)),
    ?assertEqual(?set:from_list(32, 2, [{0,1}, {4,31}]), Set1).

delete_end_test() ->
    Set0 = ?set:new(32, 2),
    Set1 = ?set:delete(30, 2, Set0),
    ?assertEqual(30, ?set:size(Set1)),
    ?assertEqual(?set:from_list(32, 2, [{0, 29}]), Set1).

delete_middle_range_test() ->
    Set0 = ?set:from_list(32, 2, [{0, 1}, {4,5}, {10, 31}]),
    Set1 = ?set:from_list(32, 2, [{0, 1}, {10, 31}]),
    ?assertEqual(Set1, ?set:delete(4, 2, Set0)),
    ?assertEqual(Set1, ?set:delete(3, 3, Set0)),
    ?assertEqual(Set1, ?set:delete(3, 4, Set0)).

delete_end_of_range_test() ->
    Set0 = ?set:from_list(32, 2, [{0, 5}, {10, 31}]),
    Set1 = ?set:from_list(32, 2, [{0, 3}, {10, 31}]),
    ?assertEqual(Set1, ?set:delete(4, 2, Set0)),
    ?assertEqual(Set1, ?set:delete(4, 3, Set0)).

delete_start_of_range_test() ->
    Set0 = ?set:from_list(32, 2, [{10, 31}]),
    Set1 = ?set:from_list(32, 2, [{12, 31}]),
    ?assertEqual(Set1, ?set:delete(8, 4, Set0)).

delete_last_byte_test() ->
    Set0 = ?set:from_list(32, 2, [{0, 5}, {10, 31}]),
    Set1 = ?set:from_list(32, 2, [{0, 4}, {10, 31}]),
    ?assertEqual(Set1, ?set:delete(5, 1, Set0)).


insert_invalid_offset_test() ->
    ?assertError(badarg, ?set:insert(-1, 0, undefined)).

insert_invalid_length_test() ->
    ?assertError(badarg, ?set:insert(0, 0, undefined)),
    ?assertError(badarg, ?set:insert(0, -1, undefined)).

insert_empty_test() ->
    Set0 = ?set:from_list(32, 2, []),
    Set1 = ?set:new(32, 2),
    ?assertEqual(Set1, ?set:insert(0, 32, Set0)).

insert_head_test() ->
    Set0 = ?set:from_list(32, 2, [{2, 31}]),
    Set1 = ?set:from_list(32, 2, [{0, 31}]),
    ?assertEqual(Set1, ?set:insert(0, 2, Set0)).

insert_after_head_test() ->
    Set0 = ?set:from_list(2,1,[]),
    Set1 = ?set:insert(0, 1, Set0),
    Set2 = ?set:insert(1, 1, Set1),
    Exp  = ?set:from_list(2,1,[{0,1}]),
    ?assertEqual(Exp, Set2).

insert_with_middle_test() ->
    Set0 = ?set:from_list(32, 2, [{0,1}, {3,4}, {6,31}]),
    Set1 = ?set:from_list(32, 2, [{0,31}]),
    ?assertEqual(Set1, ?set:insert(1, 6, Set0)).

insert_past_end_test() ->
    Set0 = ?set:new(32, 2),
    ?assertError(badarg, ?set:insert(0, 33, Set0)).

in_test_() ->
    Set0 = ?set:from_list(32, 2, [{0, 31}]),
    Set1 = ?set:from_list(32, 2, [{0, 10}, {20, 31}]),
    [ ?_assertEqual(true,  ?set:in(5, 6, Set0))
    , ?_assertEqual(true,  ?set:in(0, 32, Set0))
    , ?_assertEqual(false, ?set:in(0, 35, Set0))
    , ?_assertEqual(false, ?set:in(0, 55, Set0))

    , ?_assertEqual(true,  ?set:in(3, 4, Set1))
    , ?_assertEqual(false, ?set:in(10, 4, Set1))
    , ?_assertEqual(false, ?set:in(10, 21, Set1))
    , ?_assertEqual(false, ?set:in(0, 31, Set1))
    ].

subtract_test_() ->
    T0 = ?set:from_list(32, 2, [{10, 20}]),
    T1 = ?set:from_list(32, 2, [{10, 10}, {15, 20}]),
    T2 = ?set:from_list(32, 2, [{15, 20}]),
    [ ?_assertEqual(subtract(11, 4, T0), {T1, [{11,4}]})
    , ?_assertEqual(subtract(5, 10, T0), {T2, [{10,5}]})
    , ?_assertEqual(subtract(21, 5, T0), {T0, []})
    ].

