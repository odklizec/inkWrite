# Connect inkWrite to GitHub

The accompanying `GITHUB-SETUP-GUIDE.html` includes all four images. Open it in a browser for the illustrated guide.

This guide walks you through your first connection and test upload in **inkWrite** on an Xteink X4 Classic or X4 Pro. Have your reader with inkWrite installed on Licorice firmware that supports XTApp API 2.26, Wi‑Fi on the reader, and a phone or computer with a web browser and internet access.

You’ll create a **private repository**, which is the place on GitHub where your writing will go. You’ll also register a **GitHub App**, which is a permission record that lets inkWrite use that repository. You already have the writing app on your reader. Registering the GitHub App happens entirely on the GitHub website.

## 1. Create a free GitHub account

1. Open [GitHub’s sign-up page](https://github.com/signup) on your phone or computer. If you already have a personal GitHub account, sign in and skip to **2. Make a private place for your writing**. [GitHub sign-in](https://github.com/login)
2. Follow the prompts to enter an email address you can access, choose a strong password, and pick a username. Keep a note of your **username**. For example, if your profile is `https://github.com/alex-ink`, your username is `alex-ink`.
3. Complete any verification GitHub asks for. If GitHub sends a code or link to your email, open the message and follow its instructions. Follow GitHub’s prompts if it asks you to set up two-factor authentication.
4. Stay signed in to this same account for the rest of setup. Use a personal account you control so you can create and manage your own private repository.

## 2. Make a private place for your writing

1. Open [New repository](https://github.com/new). You can also find **New repository** in the **+** menu at the top of GitHub.
2. Under **Owner**, select your personal username. Under **Repository name**, enter `inkwrite-docs` or another name you’ll recognize. Create a dedicated repository for your writing.
3. Under visibility, choose **Private**. With this setting, access is limited to your account and anyone you explicitly grant access to. Your synced documents are stored on GitHub.
4. Turn on **Add README** (sometimes shown as **Add a README file**). This adds a starter file so GitHub creates the first **branch**, usually `main`. A branch is the version of the repository that inkWrite will use.
5. Leave the other starter-file options at their defaults. Click **Create repository**. On the new page, check that the repository says **Private** and contains `README.md`. Note the branch name shown above the file list. [GitHub’s repository instructions](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)

## 3. Register a GitHub App for inkWrite

1. Open [New GitHub App](https://github.com/settings/apps/new). To get there from your profile menu, choose **Settings → Developer settings → GitHub Apps → New GitHub App**. If you’re on a narrow screen, GitHub’s settings can be easier to use on a computer.
2. Fill in the form using the table below. If GitHub says the name is taken, add something unique to it.

| GitHub field | What to enter or select |
| --- | --- |
| **GitHub App name** | A unique name you’ll recognize, such as `inkWrite-alex-ink`. You’ll see it again when you approve the connection. |
| **Homepage URL** | The full address of your GitHub profile, such as `https://github.com/alex-ink`. Use your own username. |
| **Callback URL** and **Setup URL** | Leave both blank. |
| **Expire user authorization tokens** | Leave this checked. |
| **Request user authorization (OAuth) during installation** | Leave this unchecked. You’ll approve sign-in from inkWrite later. |
| **Enable Device Flow** | Check this. It lets you approve your reader using a short code on GitHub. |
| **Webhook → Active** | Uncheck **Active**. Leave any webhook address and secret blank. |
| **Permissions → Repository permissions → Contents** | Choose **Read & write** so inkWrite can read and save documents. |
| **Permissions → Repository permissions → Metadata** | **Read-only**. GitHub normally adds this automatically. |
| **All other permissions** | Leave at **No access**. inkWrite checks that the App has only Contents and Metadata permissions. |
| **Where can this GitHub App be installed?** | Choose **Only on this account**. |

3. Click **Create GitHub App**. On its settings page, usually under **General**, find the **Client ID** and the **App ID**. Copy both somewhere you can refer to while entering them on the reader. The Client ID contains letters and numbers. The App ID is a number. Together with your GitHub username, these are the only values you type into inkWrite’s setup form. Keep your GitHub password for the GitHub website, and leave any client secret, private key, or personal access token options unused. [GitHub’s App registration instructions](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)

## 4. Give the GitHub App access to your writing repository

1. In your new GitHub App’s settings, choose **Install App** from the sidebar. If you closed the page, open [your GitHub Apps](https://github.com/settings/apps), find your App, click **Edit**, and then choose **Install App**.
2. Click **Install** next to your own GitHub account. Choose **Only select repositories**, open the repository picker, and pick just the private writing repository you created in step 2.
3. Check that the permission summary gives the App read and write access to **Contents** and read access to **Metadata**. Click **Install** to confirm. If GitHub asks you to verify your identity again, complete that on `github.com`. [GitHub’s App installation instructions](https://docs.github.com/en/apps/using-github-apps/installing-your-own-github-app)

## 5. Approve the connection on your reader

1. Connect the reader to Wi‑Fi, open inkWrite and choose **Settings → More → GitHub sync**. On a fresh setup, this takes you straight to **GitHub setup**. If a destination is already configured, choose **Settings → Set up or change repository** from the sync screen. Use **Next** if the screen has another page. On the Classic, use the direction buttons and **OK** to select entries. On the Pro, you can tap them.
2. Select **Client ID**, **App ID**, and **GitHub login** one at a time. Enter the two IDs from your GitHub App’s settings and the username you chose when you signed up. Use the username by itself, without `@`, spaces, or `https://github.com/`.
3. Choose **Sign in and choose repository**.

   [View screenshot](images/github-setup/inkwrite-setup.png) — inkWrite setup screen showing Client ID, App ID, GitHub login, and Sign in and choose repository.

4. Leave inkWrite open. When the sign-in code appears, scan the QR with your phone’s camera or open [GitHub’s device sign-in page](https://github.com/login/device) on your phone or computer. The QR opens the sign-in page. Type the short code shown on **your** reader into GitHub, then follow the prompts. Check that GitHub shows the personal account and App name you expect before you approve. The code is temporary and should be entered only on GitHub. [GitHub’s explanation of device sign-in](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app#using-the-device-flow-to-generate-a-user-access-token)

   [View screenshot](images/github-setup/inkwrite-device-code.png) — inkWrite approval screen showing github.com/login/device, the sample code ABCD-EFGH, and a QR code for the sign-in page.

5. Return to your reader and wait for **Choose private repository**. Select your writing repository, for example `alex-ink/inkwrite-docs`. Under **Choose branch**, select the branch you noted earlier, usually `main`.
6. Check the repository, username, and branch on the confirmation screen, then select **Save and use this setup**. inkWrite keeps that destination and uses the approval you just completed. Your writing stays on the SD card until you choose to sync it. **Automatic uploads** start **Off**.

   [View screenshot](images/github-setup/inkwrite-save-setup.png) — inkWrite confirmation showing the example private repository, username, branch, and Save and use this setup.

*The inkWrite images are rendered from version 1.0.21 with sample values. The code `ABCD-EFGH` is for illustration.*

## 6. Check with one test document

1. Return to the writing screen. Choose **New**, create a short plain-text or Markdown document, and type a harmless line such as `My first inkWrite sync.` Choose **Save**. Use a fresh, recognizable name such as `First-sync-test.txt` for plain text.
2. Open **Settings → More → GitHub sync**. Check the repository and branch at the top. Under **Settings**, confirm that **GitHub sync** is **On**. Go Back and choose **Sync this document**. If approval is needed again, follow the code on the reader. A Bluetooth keyboard can also use **Ctrl+G** from the writing screen to start sync.

   [View screenshot](images/github-setup/inkwrite-sync.png) — inkWrite GitHub sync screen showing the example repository on main, connected status, and Sync this document.

3. Wait for **Synced**. On your phone or computer, open your private repository, choose the same branch, refresh the page, and open the **`documents`** folder. Open your test file and check that it contains your line. inkWrite creates the folder with the first successful upload.

**Save** normally saves to the reader’s SD card. Use **Sync this document** whenever you want to sync the open, saved file. If you later enable **Automatic uploads**, do so from the GitHub **Settings** after checking the destination. To bring a GitHub document onto the reader, use **Browse remote documents**, select a file, and choose **Download as local copy**.

## Choose whether to stay signed in

The saved setup keeps your repository and branch for the next visit. By default, approval lasts for the current session. When prompted on a later connection, choose **Connect for this session only** to approve temporarily. To let inkWrite reconnect without asking each time when GitHub allows it, choose **Remember connection on this device** or **Remember and connect** and read the notice before confirming. Remembering saves reusable sign-in credentials on the SD card without encryption. Anyone with access to that card can recover them.

To remove the saved sign-in from the reader, choose **Forget saved connection**. **Disconnect for now** ends the current session and keeps a remembered sign-in. To cancel the App’s permission on GitHub, go to [GitHub → Settings → Applications](https://github.com/settings/applications), find it under **Authorized GitHub Apps**, and revoke it. To remove its repository access, uninstall it from **Installed GitHub Apps**.

## If something goes wrong

| What you see | What to check |
| --- | --- |
| **Enter a valid public Client ID, numeric App ID and GitHub login** | Copy the **Client ID** and **App ID** from the same GitHub App’s settings. Check that the App ID is digits only and that the login is your username. Remove any extra spaces. |
| **Enable device flow** or a code never appears | Edit your GitHub App, turn on **Enable Device Flow**, and save the App’s settings. Also check the reader’s Wi‑Fi. Go **Back** in inkWrite and start sign-in again. |
| The code expired, or GitHub shows a different account | Go **Back** in inkWrite and start sign-in again for a fresh code. On GitHub, switch to the same personal account you entered in inkWrite and check the App name before approving. |
| **Install this App** or **Use selected repositories** | Confirm you installed that same App on your personal account using **Only select repositories**, with **Contents → Read & write** and **Metadata → Read-only** as its only permissions. If GitHub asks you to approve changed permissions on the installation, finish that step before retrying. |
| The repository or branch is missing | Confirm the repository belongs to your personal account, is private and active, and is selected in the App’s installation. If you skipped the README, use GitHub’s **creating a new file** link on the empty repository page, name the file `README.md`, add a line, and use **Commit changes** to save it. Then retry and choose an existing simple branch such as `main`. |
| GitHub refuses the test upload | Check that you’re connected, **GitHub sync** is **On**, the test is saved as a short `.txt` or `.md` file, and the branch allows direct changes. Check the exact repository and branch again before retrying. |
| inkWrite offers **Review both versions** or **Update local document** | There is already a version on GitHub. For a first test, save a new document with a different filename. For real writing, read both versions before choosing which to keep. |

To switch destinations later, open **GitHub sync → Settings → Set up or change repository**. Choose **Switch to a saved repository** and confirm the destination. Use **Connect** to verify access. Each setup keeps its own sync records and queued uploads. Switching turns automatic uploads off.
