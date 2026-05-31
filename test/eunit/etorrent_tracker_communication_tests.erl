-module(etorrent_tracker_communication_tests).
-include_lib("eunit/include/eunit.hrl").

identify_url_type_test_() ->
    [?_assertEqual(http,  etorrent_tracker_communication:identify_url_type(
                            "http://tracker.example.com:1234/announce")),
     ?_assertEqual(http,  etorrent_tracker_communication:identify_url_type(
                            "https://tracker.example.com:1234/announce"))
    ].
