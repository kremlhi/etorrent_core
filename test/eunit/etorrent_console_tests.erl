-module(etorrent_console_tests).

-include_lib("eunit/include/eunit.hrl").

sort_records_test_() ->
    Unsorted = [etorrent_console:test_torrent(1),
                etorrent_console:test_torrent(3),
                etorrent_console:test_torrent(2)],
    Sorted = etorrent_console:sort_records(Unsorted),
    [R1, R2, R3] = Sorted,

    [?_assertEqual(etorrent_console:test_torrent_id(R1), 1)
    ,?_assertEqual(etorrent_console:test_torrent_id(R2), 2)
    ,?_assertEqual(etorrent_console:test_torrent_id(R3), 3)
    ].
