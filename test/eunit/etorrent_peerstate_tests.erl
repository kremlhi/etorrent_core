-module(etorrent_peerstate_tests).

-include_lib("eunit/include/eunit.hrl").

-define(state, etorrent_peerstate).
-define(pset, etorrent_pieceset).
-define(rqueue, etorrent_rqueue).

testsize() -> 8.

defaults_test_() ->
    State = ?state:new(testsize()),
    [?_assert(?state:choked(State)),
     ?_assertNot(?state:interested(State)),
     ?_assertNot(?state:seeder(State)),
     ?_assertEqual(0, ?rqueue:size(?state:requests(State))),
     ?_assertNot(?state:needreqs(State)),
     ?_assertError(badarg, ?state:pieces(State)),
     ?_assertError(badarg, ?state:interesting(0, State))].

initset_test_() ->
    State = ?state:new(testsize()),
    P0 = ?state:pieces(?state:hasone(0, State)),
    P1 = ?state:pieces(?state:hasset(<<1:1, 0:7>>, State)),
    P2 = ?state:pieces(?state:hasall(State)),
    P3 = ?state:pieces(?state:hasnone(State)),
    [?_assertEqual(?pset:from_list([0], testsize()), P0),
     ?_assertEqual(?pset:from_list([0], testsize()), P1),
     ?_assertEqual(?pset:from_list([0,1,2,3,4,5,6,7], testsize()), P2),
     ?_assertEqual(?pset:from_list([], testsize()), P3)].

immutable_set_test_() ->
    S0 = ?state:new(testsize()),
    S1 = ?state:hasnone(S0),
    [?_assertError(badarg, ?state:hasset(<<1:1, 0:7>>, S1)),
     ?_assertError(badarg, ?state:hasall(S1)),
     ?_assertError(badarg, ?state:hasnone(S1)),
     ?_assertEqual(?state:hasone(0, S0), ?state:hasone(0, S1))].

seeder_revert_test_() ->
    S0 = ?state:new(testsize()),
    S1 = ?state:seeder(true, S0),
    [?_assert(?state:seeder(S1)),
     ?_assertError(badarg, ?state:seeder(false, S1))].

consistent_choked_test_() ->
    S0 = ?state:new(testsize()),
    S1 = ?state:choked(false, S0),
    [?_assertError(badarg, ?state:choked(true, S0)),
     ?_assertError(badarg, ?state:choked(false, S1)),
     ?_assertNot(?state:choked(S1))].

consistent_interested_test_() ->
    S0 = ?state:new(testsize()),
    S1 = ?state:interested(true, S0),
    [?_assertError(badarg, ?state:interested(false, S0)),
     ?_assertError(badarg, ?state:interested(true, S1)),
     ?_assert(?state:interested(S1))].

interesting_received_test_() ->
    S0 = ?state:new(testsize()),
    S1 = ?state:hasone(7, S0),
    S2 = ?state:interested(true, S1),
    [?_assertEqual(S1, ?state:interesting(7, S1)),
     ?_assert(?state:interested(?state:interesting(6, S1))),
     ?_assertEqual(S2, ?state:interesting(7, S2)),
     ?_assertEqual(S2, ?state:interesting(6, S2))].

interesting_sent_test_() ->
    L0 = ?state:interested(true, ?state:hasnone(?state:new(testsize()))),
    L1 = ?state:hasone(0, L0),
    L2 = ?state:hasone(1, L1),
    L3 = ?state:interested(false, L1),

    R0 = ?state:hasnone(?state:new(testsize())),
    R1 = ?state:hasone(0, R0),
    R2 = ?state:hasone(1, R1),

    [?_assertEqual(L1, ?state:interesting(0, R0, L1)),
     ?_assertNot(?state:interested(?state:interesting(0, R1, L1))),
     ?_assertEqual(L1, ?state:interesting(0, R2, L1)),
     ?_assertNot(?state:interested(?state:interesting(0, R2, L2))),
     ?_assertEqual(L3, ?state:interesting(0, R1, L3))].

seeding_test_() ->
    S0 = ?state:new(testsize()),
    [?_assert(?state:seeding(?state:hasall(S0))),
     ?_assertNot(?state:seeding(?state:hasnone(S0))),
     ?_assertNot(?state:seeding(?state:hasone(0, S0)))].

needreq_test_() ->
    S0 = ?state:hasnone(?state:new(testsize())),
    S1 = ?state:interested(true, S0),
    S2 = ?state:choked(false, S0),
    S3 = ?state:interested(true, ?state:choked(false, S0)),
    [?_assertNot(?state:needreqs(S0)),
     ?_assertNot(?state:needreqs(S1)),
     ?_assertNot(?state:needreqs(S2)),
     ?_assert(?state:needreqs(S3))].

request_update_test() ->
    S0 = ?state:hasnone(?state:new(testsize())),
    Reqs = ?state:requests(S0),
    NewReqs = ?rqueue:push(0, 0, 1, Reqs),
    S1 = ?state:requests(NewReqs, S0),
    ?assertEqual(NewReqs, ?state:requests(S1)).

