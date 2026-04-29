
# How to setup your local environment
1. Clone repo → Open in VS Code
2. Run `uv venv && uv pip install -r requirements.txt`
3. Copy `.env.example` → `.env` and fill credentials
4. Open `notebooks/demo.ipynb` and run the first cell
5. If all imports work → you're ready!

# UPDATE LOCAL MAIN BRANCH
1. Make sure you're on main
git switch main
2. Fetch the latest changes from remote
git fetch origin
3. Update your local main to match remote
git pull origin main
or
git reset --hard origin/main


# CREATE NEW FEAT BRANCH
1. Make sure you’re on main and up-to-date
git fetch origin → updates your local knowledge of remote branches.
git switch main → moves you onto the main branch.
git pull origin main → brings in the latest commits from GitHub.
2. Create your new feature branch
git switch -c feature/my_new_task
3. Push it to GitHub
git push -u origin feature/my-new-task
4. start coding

# PUSH BACK ALL FEATURE BRANCH
1. Check your branch (make sure you're on feat brance)
git status
2. Stage your changes
git add .
3. Commit with a clear message
git commit -m "feat: add sales_wk0 model with tests"
4. Push your branch
Push your branch to the remote so your teammate can see it
git push -u origin feature/my_task_name

# PUSH ONLY A FOLDER BACK FEATURE BRANCH
1. Check your branch (make sure you're on feat brance)
git status
2. Stage your changes
git add fabricspace
3. Commit with a clear message
git commit -m "feat: add sales_wk0 model with tests"
4. Push your branch
Push your branch to the remote so your teammate can see it
git push -u origin feature/my_task_name

# FIX THE SAME PULL REQUEST IN GIT (PR)
git status
git add .
git commit --amend --no-edit
git push --force-with-lease origin feature/your-branch