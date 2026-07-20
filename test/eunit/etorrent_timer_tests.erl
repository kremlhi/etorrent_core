-module(etorrent_timer_tests).

-include_lib("eunit/include/eunit.hrl").

-define(timer, etorrent_timer).

assertMessage(Msg) ->
    receive
        Msg ->
            ?assert(true);
        Other ->
            ?assertEqual(Msg, Other)
        after 0 ->
            ?assertEqual(Msg, make_ref())
    end.

assertNoMessage() ->
    Ref = {no_message, make_ref()},
    self() ! Ref,
    receive
        Ref ->
            ?assert(true);
        Other ->
            ?assertEqual(Ref, Other)
    end.


%% @doc Run tests inside clean processes.
timer_test_() ->
    {spawn, [ ?_test(instant_send_case())
            , ?_test(instant_timeout_case())
            , ?_test(step_and_fire_case())
            , ?_test(cancel_and_step_case())
            , ?_test(step_and_cancel_case())
            , ?_test(duplicate_cancel_case())
            ]}.


instant_send_case() ->
    {ok, Pid} = ?timer:start_link(instant),
    Msg = make_ref(),
    Ref = ?timer:send_after(Pid, 1000, self(), Msg),
    assertMessage(Msg).


instant_timeout_case() ->
    {ok, Pid} = ?timer:start_link(instant),
    Msg = make_ref(),
    Ref = ?timer:start_timer(Pid, 1000, self(), Msg),
    assertMessage({timeout, Ref, Msg}).


step_and_fire_case() ->
    {ok, Pid} = ?timer:start_link(queue),
    ?timer:send_after(Pid, 1000, self(), a),
    Ref = ?timer:start_timer(Pid, 3000, self(), b),
    ?timer:send_after(Pid, 6000, self(), c),

    ?assertEqual(1000, ?timer:step(Pid)),
    ?assertEqual(0, ?timer:step(Pid)),
    ?assertEqual(1, ?timer:fire(Pid)),
    assertMessage(a),

    ?assertEqual(2000, ?timer:step(Pid)),
    ?assertEqual(0, ?timer:step(Pid)),
    ?assertEqual(1, ?timer:fire(Pid)),
    assertMessage({timeout, Ref, b}),

    ?assertEqual(3000, ?timer:step(Pid)),
    ?assertEqual(0, ?timer:step(Pid)),
    ?assertEqual(1, ?timer:fire(Pid)),
    assertMessage(c).


cancel_and_step_case() ->
    {ok, Pid} = ?timer:start_link(queue),
    Msg = make_ref(),
    Ref = ?timer:start_timer(Pid, 6000, self(), Msg),
    ?assertEqual(6000, ?timer:cancel(Pid, Ref)),
    ?assertEqual(0, ?timer:step(Pid)),
    assertNoMessage().


step_and_cancel_case() ->
    {ok, Pid} = ?timer:start_link(queue),
    Ref = ?timer:send_after(Pid, 500, self(), a),
    500 = ?timer:step(Pid),
    ?assertEqual(false, ?timer:cancel(Pid, Ref)),
    assertMessage(a).


duplicate_cancel_case() ->
    {ok, Pid} = ?timer:start_link(queue),
    Ref = ?timer:send_after(Pid, 500, self(), b),
    ?assertEqual(500, ?timer:cancel(Pid, Ref)),
    ?assertEqual(false, ?timer:cancel(Pid, Ref)).

