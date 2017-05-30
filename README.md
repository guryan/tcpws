Set ``TcpWs::AppHost`` in ``lib/tcpws.rb`` to your heroku app.

Run:

``
sed 's/tcpws.herokuapp.com/'"$(heroku create | tail -n1 | awk '{ print $1 }' | sed 's/https:\/\///')" lib/tcpws.rb | tee > tcpws.rb && mv tcpws.rb lib/
``

``
    git add lib/tcpws.rb
``

``
    git commit -m "Set TcpWs::AppHost in lib/tcpws.rb"
``

``
    git push heroku master 
``

``
    SERVER_PORT=8080 bin/client
``

``
    heroku open
``

Now your heroku app will proxy to your local ``SERVER_PORT``
You can also open ``/logger`` to see what are going on.