-module(etorrent_chunkstate_tests).

-include_lib("eunit/include/eunit.hrl").

-define(chunkstate, etorrent_chunkstate).

flush() ->
    {messages, Msgs} = erlang:process_info(self(), messages),
    [receive Msg -> Msg end || Msg <- Msgs].

pop() -> etorrent_utils:first().
make_pid() -> spawn(fun erlang:now/0).

chunkstate_test_() ->
    {foreach,local,
        fun() -> flush() end,
        fun(_) -> flush() end,
        [?_test(test_request()),
         ?_test(test_requests()),
         ?_test(test_assigned()),
         ?_test(test_assigned_list()),
         ?_test(test_dropped()),
         ?_test(test_dropped_list()),
         ?_test(test_dropped_all()),
         ?_test(test_fetched()),
         ?_test(test_stored()),
         ?_test(test_forward()),
         ?_test(test_contents())]}.

test_request() ->
    Peer = self(),
    Set  = make_ref(),
    Num  = make_ref(),
    Srv = spawn_link(fun() ->
        etorrent_utils:reply(fun({chunk, {request, Num, Set, Peer}}) -> ok end)
    end),
    ?assertEqual(ok, ?chunkstate:request(Num, Set, Srv)).

test_requests() ->
    Ref = make_ref(),
    Srv = spawn_link(fun() ->
        etorrent_utils:reply(fun({chunk, requests}) -> Ref end)
    end),
    ?assertEqual(Ref, ?chunkstate:requests(Srv)).

test_assigned() ->
    Pid = make_pid(),
    ok = ?chunkstate:assigned(1, 2, 3, Pid, self()),
    ?assertEqual({chunk, {assigned, 1, 2, 3, Pid}}, pop()).

test_assigned_list() ->
    Pid = make_pid(),
    Chunks = [{1, 2, 3}, {4, 5, 6}],
    ok = ?chunkstate:assigned(Chunks, Pid, self()),
    ?assertEqual({chunk, {assigned, 1, 2, 3, Pid}}, pop()),
    ?assertEqual({chunk, {assigned, 4, 5, 6, Pid}}, pop()).

test_dropped() ->
    Pid = make_pid(),
    ok = ?chunkstate:dropped(1, 2, 3, Pid, self()),
    ?assertEqual({chunk, {dropped, 1, 2, 3, Pid}}, pop()).

test_dropped_list() ->
    Pid = make_pid(),
    Chunks = [{1, 2, 3}, {4, 5, 6}],
    ok = ?chunkstate:dropped(Chunks, Pid, self()),
    ?assertEqual({chunk, {dropped, 1, 2, 3, Pid}}, pop()),
    ?assertEqual({chunk, {dropped, 4, 5, 6, Pid}}, pop()).

test_dropped_all() ->
    Pid = make_pid(),
    ok = ?chunkstate:dropped(Pid, self()),
    ?assertEqual({chunk, {dropped, Pid}}, pop()).

test_fetched() ->
    Pid = make_pid(),
    ok = ?chunkstate:fetched(1, 2, 3, Pid, self()),
    ?assertEqual({chunk, {fetched, 1, 2, 3, Pid}}, pop()).

test_stored() ->
    Pid = make_pid(),
    ok = ?chunkstate:stored(1, 2, 3, Pid, self()),
    ?assertEqual({chunk, {stored, 1, 2, 3, Pid}}, pop()).

test_contents() ->
    ok = ?chunkstate:contents(1, 2, 3, <<1,2,3>>, self()),
    ?assertEqual({chunk, {contents, 1, 2, 3, <<1,2,3>>}}, pop()).

test_forward() ->
    Main = self(),
    Pid = make_pid(),
    {Slave, Ref} = erlang:spawn_monitor(fun() ->
        etorrent_utils:expect(go),
        ?chunkstate:forward(Main),
        etorrent_utils:expect(die)
    end),
    ok = ?chunkstate:assigned(1, 2, 3, Pid, Slave),
    ok = ?chunkstate:assigned(4, 5, 6, Pid, Slave),
    Slave ! go,
    ?assertEqual({chunk, {assigned, 1, 2, 3, Pid}}, pop()),
    ?assertEqual({chunk, {assigned, 4, 5, 6, Pid}}, pop()),
    Slave ! die,
    etorrent_utils:wait(Ref).

