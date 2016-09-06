vcl 4.0;

import vsthrottle;
import basicauth;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "VARNISH_BACKEND_HOST";
    .port = "VARNISH_BACKEND_PORT";
}

sub vcl_recv {
    if (req.url ~ "^\/robots\.txt$") {
        return(synth(200, "robots"));
    }

    if ((req.url ~ "^.*\/__health.*$") || (req.url ~ "^.*\/__gtg.*$")) {
        # skip auth and cache lookup
        return (pass);
    } elseif (!req.url ~ "^\/__[\w-]*\/.*$") {
        set req.http.Host = "HOST_HEADER";
        set req.http.X-VarnishPassThrough = "true";
    }
    
    if (req.url ~ "^\/content.*$") {
        set req.url = regsub(req.url, "content", "__cms-notifier/notify");
    } elseif (req.url ~ "^\/metadata.*$") {
        set req.url = regsub(req.url, "metadata", "__cms-metadata-notifier/notify");
    } elseif (req.url ~ "\/notification\/wordpress.*$") {
        set req.url = regsub(req.url, "notification\/wordpress", "__wordpress-notifier/content");
    } elseif (req.url ~ "\/notification\/brightcove\/content.*$") {
        set req.url = regsub(req.url, "notification\/brightcove\/content", "__brightcove-notifier/notify");
        return (pass);
    } elseif (req.url ~ "\/notification\/brightcove\/metadata.*$") {
        set req.url = regsub(req.url, "notification\/brightcove\/metadata", "__brightcove-metadata-preprocessor/notify");
        return (pass);
    }
    if (!basicauth.match("/.htpasswd",  req.http.Authorization)) {
        return(synth(401, "Authentication required"));
    }
    unset req.http.Authorization;

    # skip cache lookup
    return (pass);
}

sub vcl_synth {
    if (resp.reason == "robots") {
        synthetic({"User-agent: *
Disallow: /"});
        return (deliver);
    }
    if (resp.status == 401) {
        set resp.http.WWW-Authenticate = "Basic realm=Secured";
        set resp.status = 401;
        return (deliver);
    }
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
    if (((beresp.status == 500) || (beresp.status == 502) || (beresp.status == 503) || (beresp.status == 504)) && (bereq.method == "GET" )) {
        if (bereq.retries < 2 ) {
            return(retry);
        }
    } 
}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object here.
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
}
