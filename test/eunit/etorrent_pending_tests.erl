-module(etorrent_pending_tests).

-include_lib("eunit/include/eunit.hrl").

-define(pending, etorrent_pending).
-define(chunks, etorrent_chunkstate).
-define(expect, etorrent_utils:expect).
-define(wait, etorrent_utils:wait).
-define(ping, etorrent_utils:ping).
-define(first, etorrent_utils:first).


testid() -> 0.
testpid() -> ?pending:await_server(testid()).

setup_env() ->
    {ok, Pid} = ?pending:start_link(testid()),
    ok = ?pending:receiver(self(), Pid),
    put({pending, testid()}, Pid),
    Pid.

teardown_env(Pid) ->
    erase({pending, testid()}),
    ok = etorrent_utils:shutdown(Pid).

pending_test_() ->
    {setup, local,
        fun() -> application:start(gproc) end,
        fun(_) -> application:stop(gproc) end,
    {inorder,
    {foreach, local,
        fun setup_env/0,
        fun teardown_env/1,
    [?_test(test_registers()),
     ?_test(test_register_peer()),
     ?_test(test_register_twice()),
     ?_test(test_assigned_dropped()),
     ?_test(test_stored_not_dropped()),
     ?_test(test_dropped_not_dropped()),
     ?_test(test_drop_all_for_pid()),
     ?_test(test_change_receiver()),
     ?_test(test_drop_on_down()),
     ?_test(test_request_list())
    ]}}}.

test_registers() ->
    ?assert(is_pid(?pending:await_server(testid()))),
    ?assert(is_pid(?pending:lookup_server(testid()))).

test_register_peer() ->
    ?assertEqual(ok, ?pending:register(testpid())).

test_register_twice() ->
    ?assertEqual(ok, ?pending:register(testpid())),
    ?assertEqual(error, ?pending:register(testpid())).

test_assigned_dropped() ->
    Main = self(),
    Pid = spawn_link(fun() ->
        ok = ?pending:register(testpid()),
        Main ! assign,
        ?expect(die)
    end),
    ?expect(assign),
    ?chunks:assigned(0, 0, 1, Pid, testpid()),
    ?chunks:assigned(0, 1, 1, Pid, testpid()),
    Pid ! die,
    ?wait(Pid),
    ?expect({chunk, {dropped, 0, 0, 1, Pid}}),
    ?expect({chunk, {dropped, 0, 1, 1, Pid}}).

test_stored_not_dropped() ->
    Main = self(),
    Pid = spawn_link(fun() ->
        ok = ?pending:register(testpid()),
        Main ! assign,
        ?expect(store),
        ?chunks:stored(0, 0, 1, self(), testpid()),
        Main ! stored,
        ?expect(die)
    end),
    ?expect(assign),
    ?chunks:assigned(0, 0, 1, Pid, testpid()),
    ?chunks:assigned(0, 1, 1, Pid, testpid()),
    Pid ! store,
    ?expect(stored),
    Pid ! die,
    ?wait(Pid),
    ?expect({chunk, {dropped, 0, 1, 1, Pid}}).

test_dropped_not_dropped() ->
    Main = self(),
    Pid = spawn_link(fun() ->
        ok = ?pending:register(testpid()),
        Main ! assign,
        ?expect(drop),
        ?chunks:dropped(0, 0, 1, self(), testpid()),
        Main ! dropped,
        ?expect(die)
    end),
    ?expect(assign),
    ?chunks:assigned(0, 0, 1, Pid, testpid()),
    ?chunks:assigned(0, 1, 1, Pid, testpid()),
    Pid ! drop,
    ?expect(dropped),
    Pid ! die,
    ?wait(Pid),
    ?expect({chunk, {dropped, 0, 1, 1, Pid}}).

test_drop_all_for_pid() ->
    Main = self(),
    Pid = spawn_link(fun() ->
        ok = ?pending:register(testpid()),
        Main ! assign,
        ?expect(drop),
        ?chunks:dropped(self(), testpid()),
        Main ! dropped,
        ?expect(die)
    end),
    ?expect(assign),
    ?chunks:assigned(0, 0, 1, Pid, testpid()),
    ?chunks:assigned(0, 1, 1, Pid, testpid()),
    Pid ! drop, ?expect(dropped),
    Pid ! die, ?wait(Pid),
    self() ! none,
    ?assertEqual(none, ?first()).

test_change_receiver() ->
    Main = self(),
    Pid = spawn_link(fun() ->
        ?pending:receiver(self(), testpid()),
        {peer, Peer} = ?first(),
        ?chunks:assigned(0, 0, 1, Peer, testpid()),
        ?chunks:assigned(0, 1, 1, Peer, testpid()),
        ?pending:receiver(Main, testpid()),
        ?expect(die)
    end),
    Peer = spawn_link(fun() ->
        ?pending:register(testpid()),
        Pid ! {peer, self()},
        ?expect(die)
    end),
    ?expect({chunk, {assigned, 0, 0, 1, Peer}}),
    ?expect({chunk, {assigned, 0, 1, 1, Peer}}),
    Pid ! die,  ?wait(Pid),
    Peer ! die, ?wait(Peer).

test_drop_on_down() ->
    Peer = spawn_link(fun() -> ?pending:register(testpid()) end),
    ?wait(Peer),
    ?chunks:assigned(0, 0, 1, Peer, testpid()),
    ?expect({chunk, {dropped, 0, 0, 1, Peer}}).

test_request_list() ->
    Main = self(),
    Pid = spawn_link(fun() ->
        ?pending:register(testpid()),
        ?chunks:assigned(0, 0, 1, self(), testpid()),
        ?chunks:assigned(0, 1, 1, self(), testpid()),
        Main ! assigned,
        etorrent_utils:expect(die)
    end),
    etorrent_utils:expect(assigned),
    Requests = ?chunks:requests(testpid()),
    Pid ! die, etorrent_utils:wait(Pid),
    ?assertEqual([{Pid,{0,0,1}}, {Pid,{0,1,1}}], lists:sort(Requests)).

