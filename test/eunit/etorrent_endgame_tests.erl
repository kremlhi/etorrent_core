-module(etorrent_endgame_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_endgame, [add_assigned/2,add_assigned/3,del_assigned/3,get_assigned/1]).

-define(endgame, etorrent_endgame).
-define(pending, etorrent_pending).
-define(chunkstate, etorrent_chunkstate).

testid() -> 0.
testpid() -> ?endgame:lookup_server(testid()).
testset() -> etorrent_pieceset:from_list([0], 8).
pending() -> ?pending:lookup_server(testid()).
mainpid() -> etorrent_utils:lookup(etorrent_endgame).

setup() ->
    etorrent_utils:register(etorrent_endgame),
    {ok, PPid} = ?pending:start_link(testid()),
    {ok, EPid} = ?endgame:start_link(testid()),
    ok = ?pending:receiver(EPid, PPid),
    ok = ?pending:register(PPid),
    {PPid, EPid}.

teardown({PPid, EPid}) ->
    etorrent_utils:unregister(etorrent_endgame),
    ok = etorrent_utils:shutdown(EPid),
    ok = etorrent_utils:shutdown(PPid).



endgame_test_() ->
    {setup, local,
        fun() -> application:start(gproc) end,
        fun(_) -> application:stop(gproc) end,
    {foreach, local,
        fun setup/0,
        fun teardown/1, [
    ?_test(test_registers()),
    ?_test(test_active_one_assigned()),
    ?_test(test_active_one_dropped()),
    ?_test(test_active_one_fetched()),
    ?_test(test_active_one_stored()),
    ?_test(test_request_list())
    ]}}.

test_registers() ->
    ?assert(is_pid(?endgame:lookup_server(testid()))),
    ?assert(is_pid(?endgame:await_server(testid()))).


test_active_one_assigned() ->
    Pid = spawn_link(fun() ->
        ?pending:register(pending()),
        ?chunkstate:assigned(0, 0, 1, self(), testpid()),
        mainpid() ! assigned,
        etorrent_utils:expect(die)
    end),
    etorrent_utils:expect(assigned),
    ?assertEqual({ok, [{0, 0, 1}]}, ?chunkstate:request(1, testset(), testpid())),
    ?assertEqual({ok, assigned}, ?chunkstate:request(1, testset(), testpid())),
    Pid ! die, etorrent_utils:wait(Pid).

test_active_one_dropped() ->
    Pid = spawn_link(fun() ->
        ?pending:register(pending()),
        ?chunkstate:assigned(0, 0, 1, self(), testpid()),
        ?chunkstate:dropped(0, 0, 1, self(), testpid()),
        mainpid() ! dropped,
        etorrent_utils:expect(die)
    end),
    etorrent_utils:expect(dropped),
    ?assertEqual({ok, [{0, 0, 1}]}, ?chunkstate:request(1, testset(), testpid())),
    Pid ! die, etorrent_utils:wait(Pid).

test_active_one_fetched() ->
    %% Spawn a separate process to introduce the chunk into endgame
    Orig = spawn_link(fun() ->
        ?pending:register(pending()),
        ?chunkstate:assigned(0, 0, 1, self(), testpid()),
        mainpid() ! assigned,
        etorrent_utils:expect(die)
    end),
    etorrent_utils:expect(assigned),
    %% Spawn a process that aquires the chunk from endgame and marks it
    %% as fetched when told to. The request phase is synchronized: both
    %% fetchers must hold the chunk before either marks it fetched, or
    %% the second request races the first fetched notification and gets
    %% {ok, assigned} instead of the chunk list.
    Fetch = fun() -> spawn_link(fun() ->
        ?pending:register(pending()),
        {ok, [{0,0,1}]} = ?chunkstate:request(1, testset(), testpid()),
        mainpid() ! requested,
        etorrent_utils:expect(fetch),
        ?chunkstate:fetched(0, 0, 1, self(), testpid()),
        mainpid() ! fetched,
        etorrent_utils:expect(die)
    end) end,
    Pid0 = Fetch(),
    etorrent_utils:expect(requested),
    Pid1 = Fetch(),
    etorrent_utils:expect(requested),
    Pid0 ! fetch,
    etorrent_utils:expect(fetched),
    Pid1 ! fetch,
    etorrent_utils:expect(fetched),
    %% Expect endgame to not send out requests for the fetched chunk
    ?assertEqual({ok, assigned}, ?chunkstate:request(1, testset(), testpid())),
    Pid0 ! die, etorrent_utils:wait(Pid0),
    etorrent_utils:ping([pending(), testpid()]),
    ?assertEqual({ok, assigned}, ?chunkstate:request(1, testset(), testpid())),
    %% Expect endgame to not send out requests if two peers have fetched the request
    ?assertEqual({ok, assigned}, ?chunkstate:request(1, testset(), testpid())),
    Pid1 ! die, etorrent_utils:wait(Pid1),
    etorrent_utils:ping([pending(), testpid()]),
    %% Expect endgame to send out request if the chunk is dropped before it's stored
    ?assertEqual({ok, [{0, 0, 1}]}, ?chunkstate:request(1, testset(), testpid())),
    Orig ! die, etorrent_utils:wait(Orig).

test_active_one_stored() ->
    %% Spawn a separate process to introduce the chunk into endgame
    Orig = spawn_link(fun() ->
        ?pending:register(pending()),
        ?chunkstate:assigned(0, 0, 1, self(), testpid()),
        mainpid() ! assigned,
        etorrent_utils:expect(die)
    end),
    etorrent_utils:expect(assigned),
    %% Spawn a process that aquires the chunk from endgame and marks it as stored
    Pid = spawn_link(fun() ->
        ?pending:register(pending()),
        {ok, [{0,0,1}]} = ?chunkstate:request(1, testset(), testpid()),
        ?chunkstate:fetched(0, 0, 1, self(), testpid()),
        ?chunkstate:stored(0, 0, 1, self(), testpid()),
        mainpid() ! stored,
        etorrent_utils:expect(die)
    end),
    etorrent_utils:expect(stored),
    ?assertEqual({ok, assigned}, ?chunkstate:request(1, testset(), testpid())),
    Pid ! die, etorrent_utils:wait(Pid),
    etorrent_utils:ping([pending(), testpid()]),
    ?assertEqual({ok, assigned}, ?chunkstate:request(1, testset(), testpid())),
    Orig ! die, etorrent_utils:wait(Orig).

test_request_list() ->
    Pid = spawn_link(fun() ->
        ?pending:register(pending()),
        ?chunkstate:assigned(0, 0, 1, self(), testpid()),
        ?chunkstate:assigned(0, 1, 1, self(), testpid()),
        ?chunkstate:fetched(0, 1, 1, self(), testpid()),
        mainpid() ! assigned,
        etorrent_utils:expect(die)
    end),
    etorrent_utils:expect(assigned),
    Requests = ?chunkstate:requests(testpid()),
    Pid ! die, etorrent_utils:wait(Pid),
    ?assertEqual([{Pid,{0,0,1}}, {Pid,{0,1,1}}], lists:sort(Requests)).


assigned_to_noone_test() ->
    Assigned = gb_trees:empty(),
    NewAssigned = add_assigned({1,2,3}, Assigned),
    ?assertEqual({1,2,3},
                 etorrent_utils:find(fun(_) -> true end,
                                     get_assigned(NewAssigned))),
    ok.

dropped_and_reassigned_test() ->
    Pid = self(),
    Assigned1 = gb_trees:empty(),
    Assigned2 = add_assigned({1,2,3}, Pid, Assigned1),
    Assigned3 = del_assigned({1,2,3}, Pid, Assigned2),
    ?assertEqual({1,2,3},
                 etorrent_utils:find(fun(_) -> true end,
                                     get_assigned(Assigned3))),
    ok.

