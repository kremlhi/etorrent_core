-module(etorrent_progress_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_progress, [minimize_masks/3]).

-define(progress, etorrent_progress).
-define(scarcity, etorrent_scarcity).
-define(timer, etorrent_timer).
-define(pending, etorrent_pending).
-define(chunkstate, etorrent_chunkstate).
-define(piecestate, etorrent_piecestate).
-define(endgame, etorrent_endgame).

chunk_server_test_() ->
    {setup, local,
        fun() ->
            application:start(gproc),
            etorrent_torrent_ctl:register_server(testid()) end,
        fun(_) -> application:stop(gproc) end,
    {foreach, local,
        fun setup_env/0,
        fun teardown_env/1,
    [?_test(lookup_registered_case()),
     ?_test(unregister_case()),
     ?_test(register_two_case()),
     ?_test(double_check_env()),
     ?_test(assigned_case()),
     ?_test(assigned_valid_case()),
     ?_test(request_one_case()),
     ?_test(mark_dropped_case()),
     ?_test(mark_all_dropped_case()),
     ?_test(drop_none_on_exit_case()),
     ?_test(drop_all_on_exit_case()),
     ?_test(marked_stored_not_dropped_case()),
     ?_test(mark_valid_not_stored_case()),
     ?_test(mark_valid_stored_case()),
     ?_test(all_stored_marks_stored_case()),
     ?_test(get_all_request_case()),
     ?_test(unassigned_to_assigned_case()),
     ?_test(trigger_endgame_case())
     ]}}.


testid() -> 2.

setup_env() ->
    Sizes = [{0, 2}, {1, 2}, {2, 2}],
    Valid = etorrent_pieceset:empty(length(Sizes)),
    Unwanted = etorrent_pieceset:empty(length(Sizes)),
    Wishes = [],
    {ok, Time} = ?timer:start_link(queue),
    {ok, PPid} = ?pending:start_link(testid()),
    {ok, EPid} = ?endgame:start_link(testid()),
    {ok, SPid} = ?scarcity:start_link(testid(), Time, 8),
    {ok, CPid} = ?progress:start_link(
                   [testid(), 1, Valid, Sizes, self(), Wishes, Unwanted]),
    ok = ?pending:register(PPid),
    ok = ?pending:receiver(CPid, PPid),
    {Time, EPid, PPid, SPid, CPid}.

scarcity() -> ?scarcity:lookup_server(testid()).
pending()  -> ?pending:lookup_server(testid()).
progress() -> ?progress:lookup_server(testid()).
endgame()  -> ?endgame:lookup_server(testid()).

teardown_env({Time, EPid, PPid, SPid, CPid}) ->
    ok = etorrent_utils:shutdown(Time),
    ok = etorrent_utils:shutdown(EPid),
    ok = etorrent_utils:shutdown(PPid),
    ok = etorrent_utils:shutdown(SPid),
    ok = etorrent_utils:shutdown(CPid).

double_check_env() ->
    ?assert(is_pid(scarcity())),
    ?assert(is_pid(pending())),
    ?assert(is_pid(progress())),
    ?assert(is_pid(endgame())).

lookup_registered_case() ->
    ?assertEqual(true, ?progress:register_server(0)),
    ?assertEqual(self(), ?progress:lookup_server(0)).

unregister_case() ->
    ?assertEqual(true, ?progress:register_server(1)),
    ?assertEqual(true, ?progress:unregister_server(1)),
    ?assertError(badarg, ?progress:lookup_server(1)).

register_two_case() ->
    Main = self(),
    {Pid, Ref} = erlang:spawn_monitor(fun() ->
        etorrent_utils:expect(go),
        true = ?pending:register_server(20),
        Main ! registered,
        etorrent_utils:expect(die)
    end),
    Pid ! go,
    etorrent_utils:expect(registered),
    ?assertError(badarg, ?pending:register_server(20)),
    Pid ! die,
    etorrent_utils:wait(Ref).

assigned_case() ->
    Has = etorrent_pieceset:from_list([], 3),
    Ret = ?chunkstate:request(1, Has, progress()),
    ?assertEqual({ok, assigned}, Ret).

assigned_valid_case() ->
    Has = etorrent_pieceset:from_list([0], 3),
    _   = ?chunkstate:request(2, Has, progress()),
    ok  = ?chunkstate:stored(0, 0, 1, self(), progress()),
    ok  = ?chunkstate:stored( 0, 1, 1, self(), progress()),
    ok  = ?piecestate:valid(0, progress()),
    Ret = ?chunkstate:request(2, Has, progress()),
    ?assertEqual({ok, assigned}, Ret).

request_one_case() ->
    Has = etorrent_pieceset:from_list([0], 3),
    Ret = ?chunkstate:request(1, Has, progress()),
    ?assertEqual({ok, [{0, 0, 1}]}, Ret).

mark_dropped_case() ->
    Has = etorrent_pieceset:from_list([0], 3),
    {ok, [{0, 0, 1}]} = ?chunkstate:request(1, Has, progress()),
    {ok, [{0, 1, 1}]} = ?chunkstate:request(1, Has, progress()),
    ok  = ?chunkstate:dropped(0, 0, 1, self(), progress()),
    Ret = ?chunkstate:request(1, Has, progress()),
    ?assertEqual({ok, [{0, 0, 1}]}, Ret).

mark_all_dropped_case() ->
    Has = etorrent_pieceset:from_list([0], 3),
    ?assertMatch({ok, [{0, 0, 1}]}, ?chunkstate:request(1, Has, progress())),
    ?assertMatch({ok, [{0, 1, 1}]}, ?chunkstate:request(1, Has, progress())),
    ok = ?chunkstate:dropped(self(), pending()),
    ok = ?chunkstate:dropped([{0,0,1},{0,1,1}], self(), progress()),
    etorrent_utils:ping(pending()),
    etorrent_utils:ping(progress()),
    ?assertMatch({ok, [{0, 0, 1}]}, ?chunkstate:request(1, Has, progress())),
    ?assertMatch({ok, [{0, 1, 1}]}, ?chunkstate:request(1, Has, progress())).

drop_all_on_exit_case() ->
    Has = etorrent_pieceset:from_list([0], 3),
    Pid = spawn_link(fun() ->
        ok = ?pending:register(pending()),
        {ok, [{0, 0, 1}]} = ?chunkstate:request(1, Has, progress()),
        {ok, [{0, 1, 1}]} = ?chunkstate:request(1, Has, progress())
    end),
    etorrent_utils:wait(Pid),
    timer:sleep(100),
    ?assertMatch({ok, [{0, 0, 1}]}, ?chunkstate:request(1, Has, progress())),
    ?assertMatch({ok, [{0, 1, 1}]}, ?chunkstate:request(1, Has, progress())).

drop_none_on_exit_case() ->
    Has = etorrent_pieceset:from_list([0], 3),
    Pid = spawn_link(fun() ->
        ok = ?pending:register(pending())
    end),
    etorrent_utils:wait(Pid),
    ?assertMatch({ok, [{0, 0, 1}]}, ?chunkstate:request(1, Has, progress())),
    ?assertMatch({ok, [{0, 1, 1}]}, ?chunkstate:request(1, Has, progress())).

marked_stored_not_dropped_case() ->
    Has = etorrent_pieceset:from_list([0], 3),
    Pid = spawn_link(fun() ->
        ok = ?pending:register(pending()),
        {ok, [{0, 0, 1}]} = ?chunkstate:request(1, Has, progress()),
        ok = ?chunkstate:stored(0, 0, 1, self(), progress()),
        ok = ?chunkstate:stored(0, 0, 1, self(), pending())
    end),
    etorrent_utils:wait(Pid),
    ?assertMatch({ok, [{0, 1, 1}]}, ?chunkstate:request(1, Has, progress())).

mark_valid_not_stored_case() ->
    Ret = ?piecestate:valid(0, progress()),
    ?assertEqual(ok, Ret).

mark_valid_stored_case() ->
    Has = etorrent_pieceset:from_list([0,1], 3),
    {ok, [{0, 0, 1}]} = ?chunkstate:request(1, Has, progress()),
    {ok, [{0, 1, 1}]} = ?chunkstate:request(1, Has, progress()),
    ok  = ?chunkstate:stored(0, 0, 1, self(), progress()),
    ok  = ?chunkstate:stored(0, 1, 1, self(), progress()),
    ?assertEqual(ok, ?piecestate:valid(0, progress())),
    ?assertEqual(ok, ?piecestate:valid(0, progress())).

all_stored_marks_stored_case() ->
    Has = etorrent_pieceset:from_list([0,1], 3),
    {ok, [{0, 0, 1}]} = ?chunkstate:request(1, Has, progress()),
    {ok, [{0, 1, 1}]} = ?chunkstate:request(1, Has, progress()),
    ?assertMatch({ok, [{1, 0, 1}]}, ?chunkstate:request(1, Has, progress())),
    ?assertMatch({ok, [{1, 1, 1}]}, ?chunkstate:request(1, Has, progress())).

get_all_request_case() ->
    Has = etorrent_pieceset:from_list([0,1,2], 3),
    {ok, [{0, 0, 1}]} = ?chunkstate:request(1, Has, progress()),
    {ok, [{0, 1, 1}]} = ?chunkstate:request(1, Has, progress()),
    {ok, [{1, 0, 1}]} = ?chunkstate:request(1, Has, progress()),
    {ok, [{1, 1, 1}]} = ?chunkstate:request(1, Has, progress()),
    {ok, [{2, 0, 1}]} = ?chunkstate:request(1, Has, progress()),
    {ok, [{2, 1, 1}]} = ?chunkstate:request(1, Has, progress()),
    ?assertEqual({ok, assigned}, ?chunkstate:request(1, Has, progress())).

unassigned_to_assigned_case() ->
    Has = etorrent_pieceset:from_list([0], 3),
    {ok, [{0,0,1}, {0,1,1}]} = ?chunkstate:request(2, Has, progress()),
    ?assertEqual({ok, assigned}, ?chunkstate:request(1, Has, progress())).

trigger_endgame_case() ->
    %% Endgame should be triggered if all pieces have been begun and all
    %% remaining chunk requests have been assigned to peer processes.
    Has = etorrent_pieceset:from_list([0,1,2], 3),
    {ok, [{0, 0, 1}, {0, 1, 1}]} = ?chunkstate:request(2, Has, progress()),
    {ok, [{1, 0, 1}, {1, 1, 1}]} = ?chunkstate:request(2, Has, progress()),
    {ok, [{2, 0, 1}, {2, 1, 1}]} = ?chunkstate:request(2, Has, progress()),
    {ok, assigned} = ?chunkstate:request(1, Has, progress()),
    %% endgame:is_active/1 is gone; endgame engagement is asserted below
    %% by acquiring the dropped request from the endgame process.
    {ok, assigned} = ?chunkstate:request(1, Has, progress()),
    %% Once endgame is active peers route drops to the endgame process
    %% (via the etorrent_download facade), not to the progress server.
    ?chunkstate:dropped(0, 0, 1, self(), endgame()),
    %% dropped/5 is asynchronous; sync before requesting the chunk back.
    ok = etorrent_utils:ping(endgame()),
    {ok, assigned} = ?chunkstate:request(1, Has, progress()),
    %% Assert that we can aquire only this request from the endgame process
    ?assertEqual({ok, [{0, 0, 1}]}, ?chunkstate:request(1, Has, endgame())),
    ?assertEqual({ok, assigned}, ?chunkstate:request(1, Has, endgame())),
    %% The switch_mode handover that re-announces outstanding assignments
    %% to endgame needs a full torrent_ctl, which this fixture does not
    %% run; emulate the handover for the chunks assigned before endgame.
    ok = ?chunkstate:assigned(0, 1, 1, self(), endgame()),
    ok = ?chunkstate:assigned(1, 0, 1, self(), endgame()),
    ok = ?chunkstate:assigned(1, 1, 1, self(), endgame()),
    ok = ?chunkstate:assigned(2, 0, 1, self(), endgame()),
    ok = ?chunkstate:assigned(2, 1, 1, self(), endgame()),
    ok = etorrent_utils:ping(endgame()),
    %% Mark all requests as fetched.
    ok = ?chunkstate:fetched(0, 0, 1, self(), endgame()),
    ok = ?chunkstate:fetched(0, 1, 1, self(), endgame()),
    ok = ?chunkstate:fetched(1, 0, 1, self(), endgame()),
    ok = ?chunkstate:fetched(1, 1, 1, self(), endgame()),
    ok = ?chunkstate:fetched(2, 0, 1, self(), endgame()),
    ok = ?chunkstate:fetched(2, 1, 1, self(), endgame()),
    ?assertEqual(ok, etorrent_utils:ping(endgame())).


%% Directory Structure:
%%
%% Num     Path      Pieceset (indexing from 1)
%% --------------------------------------------
%%  0  /              [1-4]
%%  1  /Dir1          [1,2]
%%  2  /Dir1/File1    [1]
%%  3  /Dir1/File2    [2]
%%  4  /Dir2          [3,4]
%%  5  /Dir2/File3    [3,4]
%%
%% Check that wishlist [2, 1, 3] will be minimized to [2, 1]
minimize_masks_test_() ->
    Empty = etorrent_pieceset:new(4),
    Dir1  = etorrent_pieceset:from_bitstring(<<2#1100:4>>),
    File1 = etorrent_pieceset:from_bitstring(<<2#1000:4>>),
    File2 = etorrent_pieceset:from_bitstring(<<2#0100:4>>),
    Dir2 = File3 = etorrent_pieceset:from_bitstring(<<2#0011:4>>),

    Masks = [File1, Dir1, File2],
    Union = Empty,
    
    Masks1 = minimize_masks(Masks, Union, []),
    [?_assertEqual(Masks1, [File1,Dir1])
    ].

