-module(etorrent_peer_control_tests).

-include_lib("eunit/include/eunit.hrl").

%% Redundant wire messages must be no-ops (issue #8). These tests run
%% handle_message/2 without any server infrastructure; if a redundant
%% message reached the side-effecting code it would crash on the missing
%% servers, so returning the state unchanged also proves the early return.
redundant_message_test_() ->
    %% etorrent_peerstate:new/1 yields choked=true, interested=false
    Choked     = etorrent_peerstate:new(8),
    Unchoked   = etorrent_peerstate:choked(false, etorrent_peerstate:new(8)),
    Interested = etorrent_peerstate:interested(true, etorrent_peerstate:new(8)),
    ChokedState     = etorrent_peer_control:test_state(
                        Choked, etorrent_peerstate:new(8)),
    UnchokedState   = etorrent_peer_control:test_state(
                        Unchoked, etorrent_peerstate:new(8)),
    InterestedState = etorrent_peer_control:test_state(
                        etorrent_peerstate:new(8), Interested),
    UninterestedState = etorrent_peer_control:test_state(
                          etorrent_peerstate:new(8), etorrent_peerstate:new(8)),
    [?_assertEqual({ok, ChokedState},
                   etorrent_peer_control:handle_message(choke, ChokedState))
    ,?_assertEqual({ok, UnchokedState},
                   etorrent_peer_control:handle_message(unchoke, UnchokedState))
    ,?_assertEqual({ok, InterestedState},
                   etorrent_peer_control:handle_message(interested, InterestedState))
    ,?_assertEqual({ok, UninterestedState},
                   etorrent_peer_control:handle_message(not_interested, UninterestedState))
    ].
