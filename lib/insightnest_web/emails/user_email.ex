defmodule InsightnestWeb.UserEmail do
  import Swoosh.Email

  def passcode_email(email, code) do
    new()
    |> to(email)
    |> from({"InsightNest", "hello@insightnest.app"})
    |> subject("Your InsightNest sign-in code: #{code}")
    |> text_body("""
    Your InsightNest sign-in code is:

    #{code}

    This code expires in 10 minutes.
    If you didn't request this, you can safely ignore this email.
    """)
    |> html_body("""
    <!DOCTYPE html>
    <html>
    <body style="font-family: system-ui, sans-serif; background: #0c0a09; color: #f5f5f4; padding: 2rem; max-width: 480px; margin: 0 auto;">
      <div style="text-align: center; margin-bottom: 2rem;">
        <span style="font-size: 1.5rem; color: #8b5cf6;">⬡</span>
        <h1 style="font-size: 1.25rem; font-weight: 400; color: #f5f5f4; margin: 0.5rem 0;">InsightNest</h1>
      </div>
      <p style="color: #a8a29e; margin-bottom: 1.5rem; text-align: center;">Your sign-in code:</p>
      <div style="text-align: center; margin: 2rem 0;">
        <span style="font-family: monospace; font-size: 2.5rem; letter-spacing: 0.5rem;
                     color: #8b5cf6; background: #1c1917; padding: 1rem 2rem;
                     border-radius: 0.75rem; border: 1px solid #292524;">
          #{code}
        </span>
      </div>
      <p style="color: #78716c; font-size: 0.875rem; text-align: center;">
        Expires in 10 minutes. Didn't request this? Ignore this email.
      </p>
    </body>
    </html>
    """)
  end
end
