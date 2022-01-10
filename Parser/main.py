import Configuration
from BugCommit import Distribution
from BugCommit import PatchRelatedCommits
from BugCommit.filter import PatchCommitsFilter
# from BugCommit.filter import PatchCommitsMultiThreadFilter

if __name__ == "__main__":
    print("===========================================")
    print("Statistics of project LOC")
    print("===========================================")
    Distribution.countLOC(Configuration.SUBJECTS_PATH)

    print("===========================================")
    print("Collect bug fixing commits")
    print("===========================================")
    PatchRelatedCommits.collectCommits(Configuration.SUBJECTS_PATH, Configuration.PATCH_COMMITS_PATH, Configuration.BUG_REPORTS_PATH)

    print("\n\n\n===========================================")
    print("Filter out non-Verilog code changes and unparseable code")
    print("===========================================")
    PatchCommitsFilter.filter(Configuration.SUBJECTS_PATH, Configuration.PATCH_COMMITS_PATH)
