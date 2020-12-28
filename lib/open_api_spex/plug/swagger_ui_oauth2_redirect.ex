defmodule OpenApiSpex.Plug.SwaggerUIOAuth2Redirect do
  @moduledoc """
  This plug will handle the callback from an OAuth server
  """
  @behaviour Plug

  import Plug.Conn

  @html """
    <!-- HTML for static distribution bundle build -->
    <!doctype html>
    <html lang="en-US">
    <title>Swagger UI: OAuth2 Redirect</title>

    <body onload="run()">
    </body>

    </html>
    <script>
        'use strict';
        function run() {
            prompt("press any key to continue");
            var oauth2 = window.opener.swaggerUIRedirectOauth2;
            console.log("oauth2", oauth2)
            var sentState = oauth2.state;
            var redirectUrl = oauth2.redirectUrl;
            var isValid, qp, arr;

            if (/code|token|error/.test(window.location.hash)) {
                qp = window.location.hash.substring(1);
            } else {
                qp = location.search.substring(1);
            }

            arr = qp.split("&")
            arr.forEach(function (v, i, _arr) { _arr[i] = '"' + v.replace('=', '":"') + '"'; })
            qp = qp ? JSON.parse('{' + arr.join() + '}',
                function (key, value) {
                    return key === "" ? value : decodeURIComponent(value)
                }
            ) : {}

            isValid = qp.state === sentState

            var flow = oauth2.auth.schema.get("flow");
            console.log("flow", flow);
            console.log("oauth2.auth.code", oauth2.auth.code);
            console.log("isValid", isValid);

            if ((flow === "accessCode" || flow === "authorizationCode") && !oauth2.auth.code) {
                if (!isValid) {
                    oauth2.errCb({
                        authId: oauth2.auth.name,
                        source: "auth",
                        level: "warning",
                        message: "Authorization may be unsafe, passed state was changed in server Passed state wasn't returned from auth server"
                    });
                }

                if (qp.code) {
                    delete oauth2.state;
                    oauth2.auth.code = qp.code;
                    var callbackOpts1 = { auth: oauth2.auth, redirectUrl: redirectUrl };
                    console.log("callbackOpts1", callbackOpts1)
                    oauth2.callback({ auth: oauth2.auth, redirectUrl: redirectUrl });
                } else {
                    let oauthErrorMsg
                    if (qp.error) {
                        oauthErrorMsg = "[" + qp.error + "]: " +
                            (qp.error_description ? qp.error_description + ". " : "no accessCode received from the server. ") +
                            (qp.error_uri ? "More info: " + qp.error_uri : "");
                    }

                    oauth2.errCb({
                        authId: oauth2.auth.name,
                        source: "auth",
                        level: "error",
                        message: oauthErrorMsg || "[Authorization failed]: no accessCode received from the server"
                    });
                }
            } else {
                var callbackOpts2 = { auth: oauth2.auth, token: qp, isValid: isValid, redirectUrl: redirectUrl };
                console.log("callbackOpts2", callbackOpts2);
                oauth2.callback({ auth: oauth2.auth, token: qp, isValid: isValid, redirectUrl: redirectUrl, state: qp.state });
            }
            // window.close();
        }
    </script>
  """

  @impl Plug
  def init(_opts), do: []

  @impl Plug
  def call(conn, _opts) do
    conn = fetch_query_params(conn)
    query_params = conn.query_params
    IO.inspect(query_params, label: "query_params")

    html = render()

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  require EEx
  EEx.function_from_string(:defp, :render, @html, [])
end
