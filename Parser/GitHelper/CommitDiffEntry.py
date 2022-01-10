class CommitDiffEntry():
    def __init__(self, commit, parentCommit, diffentry) -> None:
        self.commit = commit
        self.parentCommit = parentCommit
        self.diffentry = diffentry
    
    def getCommit(self):
        return self.commit
    
    def getParentCommit(self):
        return self.parentCommit
    
    def getDiffentry(self):
        return self.diffentry