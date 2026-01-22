export default function Privacy() {
  return (
    <article className='prose prose-neutral mt-32 !max-w-none dark:prose-invert'>
      <h1>Privacy policy for Krosty</h1>
      <p>Last updated: January 2026</p>

      <p>
        Krosty is an unofficial open-source mobile Kick client/app for iOS and
        Android. We are dedicated to protecting your privacy. Krosty does not
        collect or share any personal information. However, we may gather
        anonymous usage data and crash logs solely to improve the app. For more
        information, please refer to the sections below.
      </p>

      <h2>Third-party services</h2>
      <p>
        Krosty uses and interacts with the following services in order to
        provide the best experience possible:
      </p>

      <h3>Kick</h3>
      <p>
        Krosty uses the official Kick API to showcase live channels, connect
        to chat, and provide additional features. You can optionally log in with
        your Kick account to access user-specific features, such as sending
        chat messages and viewing your followed channels.
      </p>
      <p>
        If you log in using Kick, Krosty will only ask you for the necessary
        and required permissions to function. Krosty will then obtain your OAuth
        access token and send requests to receive and transmit data to Kick
        only on your behalf. This access token is stored and encrypted locally
        on your device only.
      </p>
      <p>
        For more information on how Kick handles your data, please refer to
        their privacy policy.
      </p>

      <h3>7TV</h3>
      <p>
        Krosty uses APIs from 7TV to display custom badges and emotes in chat.
        When you visit your own channel, Krosty will request this service using
        your public Kick ID or username to obtain emotes and badges associated
        with your channel.
      </p>
      <p>
        For more information on how 7TV handles your data, please refer to
        their privacy policy.
      </p>

      <h3>Firebase</h3>
      <p>
        Krosty utilizes Firebase for crash logs, usage data, and analytics to
        aid in the development of new features, improvements, and bug fixes. The
        collected data is anonymous and does not contain any personal
        information. You can opt out of this data collection by turning off
        crash logs and analytics in the settings.
      </p>
      <p>For more information, please refer to the Firebase privacy policy.</p>

      <h2>Privacy policy updates</h2>
      <p>
        We may occasionally update this privacy policy, and the most recent
        version will always be available on this page. We recommend reviewing
        this privacy policy periodically for any changes. Changes to this
        privacy policy become effective when they are posted on this page.
      </p>

      <h2>Contact</h2>
      <p>
        If you have any questions or suggestions about this privacy policy,
        please feel free to contact us at contact@kn0.dev.
      </p>
    </article>
  );
}
