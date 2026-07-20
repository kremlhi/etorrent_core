-module(etorrent_rqueue_tests).

-include_lib("eunit/include/eunit.hrl").

-define(rqueue, etorrent_rqueue).

empty_test_() ->
    Q0 = ?rqueue:new(),
    [?_assertEqual(0, ?rqueue:size(Q0)),
     ?_assertError(badarg, ?rqueue:pop(Q0)),
     ?_assertEqual(false, ?rqueue:peek(Q0)),
     ?_assertNot(?rqueue:is_head(0, 0, 0, Q0)),
     ?_assertNot(?rqueue:has_offset(0, 0, Q0)),
     ?_assertEqual([], ?rqueue:to_list(Q0))].

one_request_test_() ->
    Q0 = ?rqueue:new(),
    Q1 = ?rqueue:push(0, 0, 1, Q0),
    Q2 = ?rqueue:pop(Q1),
    [?_assertEqual(1, ?rqueue:size(Q1)),
     ?_assertEqual({0,0,1}, ?rqueue:peek(Q1)),
     ?_assertEqual([{0,0,1}], ?rqueue:to_list(Q1)),
     ?_assertEqual([], ?rqueue:to_list(Q2)),
     ?_assertEqual(0, ?rqueue:size(?rqueue:flush(Q1)))].

head_check_test_() ->
    Q0 = ?rqueue:new(),
    Q1 = ?rqueue:push(1, 2, 3, Q0),
    [?_assertNot(?rqueue:is_head(1, 2, 3, Q0)),
     ?_assert(?rqueue:is_head(1, 2, 3, Q1)),
     ?_assertNot(?rqueue:is_head(1, 2, 2, Q1)),
     ?_assertNot(?rqueue:is_head(1, 2, 4, Q1)),
     ?_assert(?rqueue:has_offset(1, 2, Q1)),
     ?_assertNot(?rqueue:has_offset(0, 2, Q1)),
     ?_assertNot(?rqueue:has_offset(1, 1, Q1))].

low_check_test_() ->
    Q0 = ?rqueue:new(1, 3),
    Q1 = ?rqueue:push(0, 0, 1, Q0),
    Q2 = ?rqueue:push(0, 1, 1, Q1),
    [?_assert(?rqueue:is_low(Q0)),
     ?_assert(?rqueue:is_low(Q1)),
     ?_assertNot(?rqueue:is_low(Q2)),
     ?_assertEqual({low, 3}, ?rqueue:view(Q0)),
     ?_assertEqual({low, 2}, ?rqueue:view(Q1)),
     ?_assertEqual({needs, 1}, ?rqueue:view(Q2))
     ].

needs_test_() ->
    Q0 = ?rqueue:new(1, 3),
    Q1 = ?rqueue:push(0, 0, 1, Q0),
    Q2 = ?rqueue:push(0, 1, 1, Q1),
    Q3 = ?rqueue:push(0, 2, 1, Q2),
    Q4 = ?rqueue:push(0, 3, 1, Q3),
    [?_assertEqual(3, ?rqueue:needs(Q0)),
     ?_assertEqual(2, ?rqueue:needs(Q1)),
     ?_assertEqual(1, ?rqueue:needs(Q2)),
     ?_assertEqual(0, ?rqueue:needs(Q3)),
     ?_assertEqual(full, ?rqueue:view(Q3)),
     ?_assertEqual(0, ?rqueue:needs(Q4)),
     ?_assertEqual({over_limit, 1}, ?rqueue:view(Q4))].

high_check_test_() ->
    Q0 = ?rqueue:new(1, 3),
    Q1 = ?rqueue:push([null], Q0),
    Q3 = ?rqueue:push([null, null, null], Q0),
    Q4 = ?rqueue:push([null, null, null, null], Q0),
    [?_assertEqual(false, ?rqueue:is_overlimit(Q0)),
     ?_assertEqual({low, 3}, ?rqueue:view(Q0)),
     ?_assertEqual(false, ?rqueue:is_overlimit(Q1)),
     ?_assertEqual({low, 2}, ?rqueue:view(Q1)),
     ?_assertEqual(true,  ?rqueue:is_overlimit(Q3)),
     ?_assertEqual(full, ?rqueue:view(Q3)),
     ?_assertEqual(true,  ?rqueue:is_overlimit(Q4)),
     ?_assertEqual({over_limit, 1}, ?rqueue:view(Q4))].

push_list_test_() ->
    Q0 = ?rqueue:new(),
    Q1 = ?rqueue:push(0, 0, 1, Q0),
    Q2 = ?rqueue:push([{0,1,1},{0,2,1}], Q1),
    OQ0 = ?rqueue:pop(Q2),
    OQ1 = ?rqueue:pop(OQ0),
    OQ2 = ?rqueue:pop(OQ1),
    [?_assertEqual({0,0,1}, ?rqueue:peek(Q2)),
     ?_assertEqual({0,1,1}, ?rqueue:peek(OQ0)),
     ?_assertEqual({0,2,1}, ?rqueue:peek(OQ1)),
     ?_assertEqual([{0,0,1},{0,1,1},{0,2,1}], ?rqueue:to_list(Q2)),
     ?_assertEqual([], ?rqueue:to_list(OQ2))].

member_delete_test() ->
    Q0 = ?rqueue:new(),
    Q1 = ?rqueue:push(0, 0, 1, Q0),
    Q2 = ?rqueue:push(0, 1, 1, Q1),
    ?assert(?rqueue:member(0, 0, 1, Q1)),
    ?assertNot(?rqueue:member(0, 1, 1, Q1)),
    ?assert(?rqueue:member(0, 1, 1, Q2)),
    Q3 = ?rqueue:delete(0, 1, 1, Q2),
    ?assertNot(?rqueue:member(0, 1, 1, Q3)),
    ?assert(?rqueue:member(0, 0, 1, Q3)),
    Q4 = ?rqueue:delete(0, 0, 1, Q3),
    ?assertNot(?rqueue:member(0, 0, 1, Q4)).

