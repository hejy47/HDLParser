import Configuration
from BugCommit import Distribution
from BugCommit.parser import PatchParserMultiThreadRunner

if __name__ == "__main__":

    print("===========================================")
    print("Statistics of diff hunk sizes of code changes")
    print("===========================================")
    Distribution.statistics(Configuration.PATCH_COMMITS_PATH, Configuration.DIFFENTRY_SIZE_PATH)

    print("\n\n\n===========================================")
    print("Parse code changes of patches")
    print("===========================================")
    PatchParserMultiThreadRunner.run(Configuration.PATCH_COMMITS_PATH, Configuration.PARSE_RESULTS_PATH)
