vcl 4.0;

# Define the backend server
backend default {
    .host = "<server_ip>";
    .port = "80"; # Assuming your NodeJS app is running on port 3000
}

sub vcl_recv {
  
  if (req.url ~ "^/_server-.*" || req.url ~ "^/cart*" || req.url ~ "^/_actions*") {
    return (pass); 
  }

  if(req.http.ContentType ~ "text/html" || req.url ~ "/" || req.url ~ "^/product/*"){
    return (hash); 
  }

  # Remove Accept-Encoding for static files
  if (req.http.Accept-Encoding) {
    if (req.url ~ "\.(gif|jpg|jpeg|swf|flv|mp3|mp4|pdf|ico|png|gz|tgz|bz2)(\?.*|)$") {
      unset req.http.Accept-Encoding;
    } elsif (req.http.Accept-Encoding ~ "gzip") {
      set req.http.Accept-Encoding = "gzip";
    } elsif (req.http.Accept-Encoding ~ "deflate") {
      set req.http.Accept-Encoding = "deflate";
    } else {
      unset req.http.Accept-Encoding;
    }
  }

  # Remove cookies for static files
  if (req.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
    unset req.http.cookie;
    set req.url = regsub(req.url, "\?.*$", "");
  }

  # Remove query parameters for static files
  if (req.url ~ "\?(utm_(campaign|medium|source|term)|adParams|client|cx|eid|fbid|feed|ref(id|src)?|v(er|iew))=") {
    set req.url = regsub(req.url, "\?.*$", "");
  }

  # Pass requests with cookies to the backend
  if (req.http.cookie) {
    return(pass);
  }
}

sub vcl_backend_response {
  # Don't cache responses with Set-Cookie headers
  if (beresp.http.set-cookie) {
    set beresp.uncacheable = true;
    set beresp.ttl = 120s;
    return (deliver);
  }

  # Cache static files for a long time
  if (bereq.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
    set beresp.ttl = 365d;
  }

  set beresp.ttl = 10m;
  set beresp.grace = 2m;
}

sub vcl_deliver {
  # Add a custom header to indicate cache hits
  if (obj.hits > 0) {
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }
}