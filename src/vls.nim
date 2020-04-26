import net

when is_main_module:
   var socket = new_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP, false)
   bind_addr(socket, Port(8000))
   listen(socket)
   echo "Listening on port 8000"

   var client: Socket
   var address = ""
   while true:
      accept_addr(socket, client, address)
      echo "Client connected from ", address

      # Collect the client's request.
      var request_raw = ""
      var done = false
      var par_count = 0
      while true:
         var data = ""
         try:
            data = recv(client, 1024, 1000)
         except TimeoutError:
            echo "Timeout while waiting for a complete request."
            send(client, "Timeout while waiting for a complete request.")
            close(client)
            break

         if data == "":
            echo "Connection closed from ", address
            break

         for i, c in data:
            add(request_raw, c)
            case c
            of '{':
               inc(par_count)
            of '}':
               dec(par_count)
               if par_count == 0:
                  echo "Done"
                  if i != high(data):
                     echo "error, there's still data in the TCP buffer"
                  done = true
                  break
            else:
               discard

         if done:
            break

      if not done:
         echo "Failed to collect a valid request"
         close(client)
         continue

      echo "Got request data, length ", len(request_raw)

      # Process the request.
      let response = request_raw

      # Send the reply.
      send(client, response)
      close(client)

   close(socket)
