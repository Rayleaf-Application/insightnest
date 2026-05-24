defmodule InsightnestWeb.UserEmail do
  @moduledoc false

  import Swoosh.Email

  def invitation_email(email, name) do
    greeting = if name && name != "", do: "Hi #{name},", else: "Hi,"

    new()
    |> to(email)
    |> from({"InsightNest", "hello@insightnest.xyz"})
    |> subject("You're in — InsightNest alpha access")
    |> text_body("""
    #{greeting}

    Your request for InsightNest alpha access has been approved.

    Sign in here: https://insightnest.xyz/auth

    Use the Email tab and enter this address to receive your sign-in code.
    If you prefer Ethereum wallet auth, that works too.

    Welcome to the nest.
    — InsightNest
    """)
    |> html_body("""
    <!DOCTYPE html>
    <html>
    <body style="font-family: system-ui, sans-serif; background: #141820; color: #FDFAF5; padding: 2rem; max-width: 480px; margin: 0 auto;">
      <div style="text-align: center; margin-bottom: 2rem;">
        <span style="font-size: 1.5rem; color: #C9913A; font-family: Georgia, serif; font-style: italic;">✦</span>
        <h1 style="font-family: Georgia, serif; font-size: 1.25rem; font-weight: 400; color: #FDFAF5; margin: 0.5rem 0;">
          <span style="font-style: italic;">Insight</span><span style="color: #C9913A;">Nest</span>
        </h1>
      </div>
      <p style="color: #F5F0E8; margin-bottom: 0.5rem;">#{greeting}</p>
      <p style="color: #FDFAF5; font-size: 1.1rem; margin-bottom: 1.5rem;">You're in. Your alpha access has been approved.</p>
      <div style="text-align: center; margin: 2rem 0;">
        <a href="https://insightnest.xyz/auth"
           style="display: inline-block; padding: 0.75rem 2rem; background: #C9913A;
                  color: #141820; text-decoration: none; border-radius: 0.625rem;
                  font-size: 0.9375rem; font-weight: 500;">
          Sign in to InsightNest
        </a>
      </div>
      <p style="color: #7A7468; font-size: 0.875rem; text-align: center;">
        Use the Email tab and enter this address to receive your sign-in code.
      </p>
    </body>
    </html>
    """)
  end

  def passcode_email(email, code) do
    new()
    |> to(email)
    |> from({"InsightNest", "hello@insightnest.xyz"})
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
    <body style="font-family: system-ui, sans-serif; background: #141820; color: #FDFAF5; padding: 2rem; max-width: 480px; margin: 0 auto;">
      <div style="text-align: center; margin-bottom: 2rem;">
        <span style="font-size: 1.5rem; color: #C9913A; font-family: Georgia, serif; font-style: italic;">✦</span>
        <h1 style="font-family: Georgia, serif; font-size: 1.25rem; font-weight: 400; color: #FDFAF5; margin: 0.5rem 0;">
          <span style="font-style: italic;">Insight</span><span style="color: #C9913A;">Nest</span>
        </h1>
      </div>
      <p style="color: #F5F0E8; margin-bottom: 1.5rem; text-align: center;">Your sign-in code:</p>
      <div style="text-align: center; margin: 2rem 0;">
        <span style="font-family: monospace; font-size: 2.5rem; letter-spacing: 0.5rem;
                     color: #E8B86D; background: #2D3142; padding: 1rem 2rem;
                     border-radius: 0.75rem; border: 1px solid #3d4464;">
          #{code}
        </span>
      </div>
      <p style="color: #7A7468; font-size: 0.875rem; text-align: center;">
        Expires in 10 minutes. Didn't request this? Ignore this email.
      </p>
    </body>
    </html>
    """)
  end
end
