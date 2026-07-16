-module(etorrent_tracker_communication_tests).
-include_lib("eunit/include/eunit.hrl").

identify_url_type_test_() ->
    [?_assertEqual(http,
                   etorrent_tracker_communication:identify_url_type(
                     "http://tracker.example.com:1234/announce")),
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
