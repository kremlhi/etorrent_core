-module(etorrent_tracker_communication_tests).
-include_lib("eunit/include/eunit.hrl").

identify_url_type_test_() ->
    [?_assertEqual(http,
                   etorrent_tracker_communication:identify_url_type(
                     "http://tracker.example.com:1234/announce")),
     ?_assertEqual(http,
                   etorrent_tracker_communication:identify_url_type(
                     "https://tracker.example.com:1234/announce")),
     ?_assertEqual({udp, "tracker.example.com", 1234},
                   etorrent_tracker_communication:identify_url_type(
                     "udp://tracker.example.com:1234/announce")),
     ?_assertExit(identify_url_type,
                  etorrent_tracker_communication:identify_url_type(
                    "not_a_url")),
     ?_assertExit(identify_url_type,
                  etorrent_tracker_communication:identify_url_type(
                    "ftp://tracker.example.com:1234/announce"))
    ].

contact_tracker_udp_test_() ->
    {foreach,
     fun() ->
         meck:new(etorrent_torrent,         [passthrough]),
         meck:new(etorrent_config,          [passthrough]),
         meck:new(etorrent_udp_tracker_mgr, [passthrough]),
         meck:new(etorrent_tracker,         [passthrough]),
         meck:expect(etorrent_torrent, lookup, fun(_Id) ->
             {value, [{uploaded, 0}, {downloaded, 0}, {left_or_skipped, 0}]}
         end),
         meck:expect(etorrent_config, listen_port, fun() -> 6881 end),
         meck:expect(etorrent_tracker, statechange, fun(_Id, _Changes) -> ok end)
     end,
     fun(_) ->
         meck:unload(etorrent_torrent),
         meck:unload(etorrent_config),
         meck:unload(etorrent_udp_tracker_mgr),
         meck:unload(etorrent_tracker)
     end,
     [?_test(begin
         meck:expect(etorrent_udp_tracker_mgr, announce,
                     fun(_Addr, _Props, _Timeout) -> {error, <<"connect failed">>} end),
         S = etorrent_tracker_communication:test_state(1, <<"hash">>, <<"peer">>, 5000),
         ?assertEqual(error,
                      etorrent_tracker_communication:contact_tracker_udp(
                        "udp://tracker.example.com:1234", 42,
                        {1,2,3,4}, 1234, started, S)),
         ?assert(meck:called(etorrent_tracker, statechange,
                             [42, [{message, error, <<"connect failed">>}]]))
     end),
      ?_test(begin
         meck:expect(etorrent_udp_tracker_mgr, announce,
                     fun(_Addr, _Props, _Timeout) -> timeout end),
         S = etorrent_tracker_communication:test_state(1, <<"hash">>, <<"peer">>, 5000),
         ?assertEqual(error,
                      etorrent_tracker_communication:contact_tracker_udp(
                        "udp://tracker.example.com:1234", 42,
                        {1,2,3,4}, 1234, started, S)),
         ?assert(meck:called(etorrent_tracker, statechange,
                             [42, [{message, error, <<"Timeout.">>}]]))
     end)
    ]}.

first_tracker_id_test_() ->
    [?_assertEqual(10,
                   etorrent_tracker_communication:first_tracker_id(
                     [[{10,"http://bt3.rutracker.org/ann?uk=xxxxxxxxxx"}],
                      [{11,"http://retracker.local/announce"}]]))
    ].
