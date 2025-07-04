<img src="https://github.com/user-attachments/assets/f0769d12-61dd-4f2f-91e0-79f8b0a302bb" width="200px">

# KindleFetch

<a href="https://github.com/justrals/KindleFetch"><img src="https://img.shields.io/github/stars/justrals/KindleFetch" height="25px"></a>
<a href="https://justrals.tech/donate"><img src="https://img.shields.io/badge/Donate-f09c00" height="25px"></a>

Simple CLI for downloading books from Anna's Archive directly to your Kindle without a computer.

## Prerequisites
**Your Kindle must be jailbroken before proceeding!**  
If it's not, follow [this guide](https://kindlemodding.org/) first.

**Install kterm**:
1. Download the latest release from [kterm's releases page](https://github.com/bfabiszewski/kterm/releases)
2. Unzip the archive to the `extensions` directory in your Kindle's root

**KOReader (Optional but Recommended):**

1. **Download** the latest release from the [KOReader Releases Page](https://github.com/koreader/koreader/releases)
2. **Unsure which version to get?** Check the [Installation Guide](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices#err-there-are-four-kindle-packages-to-choose-from-which-do-i-pick)
3. **Extract** the contents of the downloaded archive to the **root directory** of your Kindle

## Installation

### Automatic installation (Recomended)

1. **Launch KUAL** (Kindle Unified Application Launcher) and open **kterm**

2. **Run the installation command** in kterm:
   ```bash
   curl https://justrals.github.io/KindleFetch/install.sh | sh
   ```

3. **Complete the setup**:
   - Wait for the installation to finish (you should see a success message)
   - Type `exit` to close kterm
   - You should now see a new "KindleFetch" option in KUAL
     
### Manual Installation

1. **Download** the latest release from the [**Releases**](https://github.com/justrals/KindleFetch/releases) tab

2. **Unzip** it and move its contents into the `extensions` folder in the root directory of your **Kindle**
   - You should now see a new "KindleFetch" option in KUAL

3. Update from the main menu if asked
