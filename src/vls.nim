import net

when is_main_module:
   var socket = new_socket()
   bind_addr(socket, Port(8000))
   listen(socket)
   echo "Listening on port 8000"

   while true:
      var client: Socket
      var address = ""
      accept_addr(socket, client, address)
      echo "Client connected from ", address

      while true:
         var data = ""
         let res = recv_line(client)
         if res == "":
            echo "Connection closed to ", address
            break
         echo "Result is ", res
         echo "Data is ", data

   close(socket)
