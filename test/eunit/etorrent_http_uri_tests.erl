%% Tests for the inets_regexp → re:run migration in etorrent_http_uri.
-module(etorrent_http_uri_tests).
-include_lib("eunit/include/eunit.hrl").

parse_test_() ->
    [?_assertEqual({http, "", "tracker.example.com", 1234, "/announce", ""},
                   etorrent_http_uri:parse(
                     "http://tracker.example.com:1234/announce")),
     ?_assertEqual({http, "", "tracker.example.com", 80, "/announce", ""},
                   etorrent_http_uri:parse(
                     "http://tracker.example.com/announce")),
     ?_assertEqual({http, "", "tracker.example.com", 80, "/announce",
                    "?info_hash=abc&port=6881"},
                   etorrent_http_uri:parse(
                     "http://tracker.example.com/announce?info_hash=abc&port=6881"))].
