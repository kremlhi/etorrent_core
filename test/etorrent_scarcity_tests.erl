-module(etorrent_scarcity_tests).

-include_lib("eunit/include/eunit.hrl").

-define(scarcity, etorrent_scarcity).
-define(pieceset, etorrent_pieceset).
-define(timer, etorrent_timer).

pieces(Pieces) ->
    ?pieceset:from_list(Pieces, 8).

scarcity_server_test_() ->
    {setup,
        fun()  -> application:start(gproc) end,
        fun(_) -> application:stop(gproc) end,
        [?_test(register_case()),
         ?_test(server_registers_case()),
         ?_test(initial_ordering_case(test_data(2))),
         ?_test(empty_ordering_case(test_data(3))),
         ?_test(init_pieceset_case(test_data(4))),
         ?_test(one_available_case(test_data(5))),
         ?_test(decrement_on_exit_case(test_data(6))),
         ?_test(init_watch_case(test_data(7))),
         ?_test(add_peer_update_case(test_data(8))),
         ?_test(add_piece_update_case(test_data(9))),
         ?_test(aggregate_update_case(test_data(12))),
         ?_test(noaggregate_update_case(test_data(13))),
         ?_test(peer_exit_update_case(test_data(10))),
         ?_test(local_unwatch_case(test_data(11)))]}.

test_data(N) ->
    {ok, Time} = ?timer:start_link(queue),
    {ok, Pid} = ?scarcity:start_link(N, Time, 16),
    {N, Time, Pid}.

register_case() ->
    true = ?scarcity:register_server(0),
    ?assertEqual(self(), ?scarcity:lookup_server(0)),
    ?assertEqual(self(), ?scarcity:await_server(0)).

server_registers_case() ->
    {ok, Pid} = ?scarcity:start_link(1, 16),
    ?assertEqual(Pid, ?scarcity:lookup_server(1)).

initial_ordering_case({N, Time, Pid}) ->
    {ok, Order} = ?scarcity:get_order(N, pieces([0,1,2,3,4,5,6,7])),
    ?assertEqual([0,1,2,3,4,5,6,7], Order).

empty_ordering_case({N, Time, Pid}) ->
    {ok, Order} = ?scarcity:get_order(3, pieces([])),
    ?assertEqual([], Order).

init_pieceset_case({N, Time, Pid}) ->
    ?assertEqual(ok, ?scarcity:add_peer(4, pieces([]))).

one_available_case({N, Time, Pid}) ->
    ok = ?scarcity:add_peer(N, pieces([])),
    ?assertEqual(ok, ?scarcity:add_piece(N, 0, pieces([0]))),
    Pieces  = pieces([0,1,2,3,4,5,6,7]),
    {ok, Order} = ?scarcity:get_order(N, Pieces),
    ?assertEqual([1,2,3,4,5,6,7,0], Order).

decrement_on_exit_case({N, Time, _}) ->
    Main = self(),
    Pid = spawn_link(fun() ->
        ok = ?scarcity:add_peer(N, pieces([0])),
        ok = ?scarcity:add_piece(N, 2, pieces([0,2])),
        Main ! done,
        receive die -> ok end
    end),
    receive done -> ok end,
    Pieces  = ?pieceset:from_list([0,1,2,3,4,5,6,7], 8),
    {ok, O1} = ?scarcity:get_order(N, pieces([0,1,2,3,4,5,6,7])),
    ?assertEqual([1,3,4,5,6,7,0,2], O1),
    Ref = monitor(process, Pid),
    Pid ! die,
    receive {'DOWN', Ref, _, _, _} -> ok end,
    {ok, O2} = ?scarcity:get_order(N, Pieces),
    ?assertEqual([0,1,2,3,4,5,6,7], O2).

init_watch_case({N, Time, Pid}) ->
    {ok, Ref, Order} = ?scarcity:watch(N, seven, pieces([0,2,4,6])),
    ?assert(is_reference(Ref)),
    ?assertEqual([0,2,4,6], Order).

add_peer_update_case({N, Time, Pid}) ->
    {ok, Ref, _} = ?scarcity:watch(N, eight, pieces([0,2,4,6])),
    ?assertEqual(1, ?timer:fire(Time)),
    ok = ?scarcity:add_peer(N, pieces([0,2])),
    receive
        {scarcity, Ref, Tag, Order} ->
            ?assertEqual(eight, Tag),
            ?assertEqual([4,6,0,2], Order);
        Other ->
            ?assertEqual(make_ref(), Other)
    end.

add_piece_update_case({N, Time, Pid}) ->
    {ok, Ref, _} = ?scarcity:watch(9, nine, pieces([0,2,4,6])),
    ok = ?scarcity:add_peer(N, pieces([])),
    ok = ?scarcity:add_piece(N, 2, pieces([2])),
    ?assertEqual(5000, ?timer:step(Time)),
    ?assertEqual(1, ?timer:fire(Time)),
    receive
        {scarcity, Ref, nine, Order} ->
            ?assertEqual([0,4,6,2], Order)
    end.

aggregate_update_case({N, Time, Pid}) ->
    {ok, Ref, _} = ?scarcity:watch(N, aggr, pieces([0,2,4,6])),
    %% Assert that peer is limited by default
    ?assertEqual(5000, ?timer:step(Time)),
    ok = ?scarcity:add_peer(N, pieces([2])),
    ok = ?scarcity:add_piece(N, 0, pieces([0,2])),
    ?assertEqual(1, ?timer:fire(Time)),
    receive
        {scarcity, Ref, aggr, [4,6,0,2]} -> ok;
        Other -> ?assertEqual(make_ref(), Other)
        after 0 -> ?assert(false)
    end.

noaggregate_update_case({N, Time, Pid}) ->
    {ok, Ref, _} = ?scarcity:watch(N, aggr, pieces([0,2,4,6])),
    %% Assert that peer is limited by default
    ?assertEqual(5000, ?timer:step(Time)),
    ok = ?scarcity:add_peer(N, pieces([2])),
    ?assertEqual(1, ?timer:fire(Time)),
    receive
        {scarcity, Ref, aggr, [0,4,6,2]} -> ok;
        O1 -> ?assertEqual(make_ref(), O1)
        after 0 -> ?assert(false)
    end,
    ok = ?scarcity:add_piece(N, 0, pieces([0,2])),
    ?assertEqual(1, ?timer:fire(Time)),
    receive
        {scarcity, Ref, aggr, [4,6,0,2]} -> ok;
        O2 -> ?assertEqual(make_ref(), O2)
        after 0 -> ?assert(false)
    end.



peer_exit_update_case({N, Time, _}) ->
    Main = self(),
    Pid = spawn_link(fun() ->
        ok = ?scarcity:add_peer(N, pieces([0,1,2,3])),
        Main ! done,
        receive die -> ok end
    end),
    receive done -> ok end,
    {ok, Ref, _} = ?scarcity:watch(N, ten, pieces([0,2,4,6])),
    Pid ! die,
    ?assertEqual(1, ?timer:fire(Time)),
    receive
        {scarcity, Ref, ten, Order} ->
            ?assertEqual([0,2,4,6], Order)
    end.

local_unwatch_case({N, Time, Pid}) ->
    {ok, Ref, _} = ?scarcity:watch(N, eleven, pieces([0,2,4,6])),
    ?assertEqual(ok, ?scarcity:unwatch(N, Ref)),
    ok = ?scarcity:add_peer(N, pieces([0,1,2,3,4,5,6,7])),
    %% Assume that the message is sent before the add_peer call returns
    receive
        {scarcity, Ref, _, _} ->
            ?assert(false)
        after 0 ->
            ?assert(true)
    end.
