import os
import shutil
import Configuration
import jpype
import func_timeout
from func_timeout import func_set_timeout
from utils.StartJVM import startJVM
from utils import FileHelper

def getGumTreeDiff():
    if not jpype.isJVMStarted():startJVM()
    # init generators
    TreeGenerators = jpype.JClass("com.github.gumtreediff.gen.TreeGenerators")
    TreeGenerator = jpype.JClass("com.github.gumtreediff.gen.TreeGenerator")
    ClassIndex = jpype.JClass("org.atteo.classindex.ClassIndex")
    Register = jpype.JClass("com.github.gumtreediff.gen.Register")
    for gen in ClassIndex.getSubclasses(TreeGenerator.class_):
        a = gen.getAnnotation(Register.class_)
        if a: TreeGenerators.getInstance().install(gen, a)
    
    Matchers = jpype.JClass("com.github.gumtreediff.matchers.Matchers")
    Diff = jpype.JClass("com.github.gumtreediff.actions.Diff")
    SimplifiedChawatheScriptGenerator = jpype.JClass("com.github.gumtreediff.actions.SimplifiedChawatheScriptGenerator")
    GumtreeProperties = jpype.JClass("com.github.gumtreediff.matchers.GumtreeProperties")
    diffArr = [TreeGenerators, Matchers, Diff, SimplifiedChawatheScriptGenerator, GumtreeProperties]
    return diffArr

@func_set_timeout(60)
def diffWithTimeout(prevFile, revFile, diffArr):
    # diff
    TreeGenerators, Matchers, Diff, SimplifiedChawatheScriptGenerator, GumtreeProperties = diffArr
    # copy includeFiles to /tmp/
    prevPath = os.path.dirname(prevFile)
    for prevIncludeFile in os.listdir(prevPath):
        if prevIncludeFile == os.path.basename(prevFile):continue
        FileHelper.copyFile(os.path.join(prevPath, prevIncludeFile), os.path.join("/tmp", prevIncludeFile))
    src = TreeGenerators.getInstance().getTree(prevFile, "hdl-hdlparser")
    # delete includeFiles in /tmp/
    for prevIncludeFile in os.listdir(prevPath):
        if prevIncludeFile == os.path.basename(prevFile):continue
        FileHelper.deleteFile(os.path.join("/tmp", prevIncludeFile))

    # copy includeFiles to /tmp/
    revPath = os.path.dirname(revFile)
    for revIncludeFile in os.listdir(revPath):
        if revIncludeFile == os.path.basename(revFile):continue
        FileHelper.copyFile(os.path.join(revPath, revIncludeFile), os.path.join("/tmp", revIncludeFile))
    dst = TreeGenerators.getInstance().getTree(revFile, "hdl-hdlparser")
    # delete includeFiles in /tmp/
    for revIncludeFile in os.listdir(revPath):
        if revIncludeFile == os.path.basename(revFile):continue
        FileHelper.deleteFile(os.path.join("/tmp", revIncludeFile))
    
    properties = GumtreeProperties()
    m = Matchers.getInstance().getMatcherWithFallback("hdl-hdlparser")
    m.configure(properties)
    mappings = m.match(src.getRoot(), dst.getRoot())
    editScript = SimplifiedChawatheScriptGenerator().computeActions(mappings)
    diff = Diff(src, dst, mappings, editScript)

    # actions
    diffActions = []
    if diff: diffActions = list(diff.editScript)
    return diffActions

@func_set_timeout(30)
def parseWithTimeOut(revFile, diffArr):
    # diff
    TreeGenerators = diffArr[0]
    # copy includeFiles to /tmp/
    revPath = os.path.dirname(revFile)
    for revIncludeFile in os.listdir(revPath):
        if revIncludeFile == os.path.basename(revFile):
            continue
        revIncludeFilePath = os.path.join(revPath, revIncludeFile)
        if os.path.isfile(revIncludeFilePath):
            FileHelper.copyFile(revIncludeFilePath, os.path.join("/tmp", revIncludeFile))
        elif os.path.isdir(revIncludeFilePath):
            FileHelper.copyDirectory(revIncludeFilePath, os.path.join("/tmp", revIncludeFile))
    dst = TreeGenerators.getInstance().getTree(revFile, "hdl-hdlparser")
    # delete includeFiles in /tmp/
    for revIncludeFile in os.listdir(revPath):
        if revIncludeFile == os.path.basename(revFile):
            continue
        revIncludeFilePath = os.path.join("/tmp", revIncludeFile)
        if os.path.isfile(revIncludeFilePath):
            FileHelper.deleteFile(revIncludeFilePath)
        elif os.path.isdir(revIncludeFilePath):
            FileHelper.deleteDirectory(revIncludeFilePath)
    return dst

def parse(revFile, diffArr):
    try:
        dst = parseWithTimeOut(revFile, diffArr)
        return dst
    except func_timeout.exceptions.FunctionTimedOut:
        print("TimeOut", revFile)
        return None
    except Exception as e:
        # print("Error", revFile)
        return None

def diff(prevFile, revFile, diffArr):
    try:
        diffActions = diffWithTimeout(prevFile, revFile, diffArr)
        if len(diffActions) > 1000:
            return []
        return diffActions
    except func_timeout.exceptions.FunctionTimedOut:
        print("TimeOut")
        errorPath = os.path.join(Configuration.OUTPUT_PATH, "ParseErrorMessage.log")
        with open(errorPath, 'a+') as f:
            f.write("ParseError:\n")
            f.write(prevFile + "\n")
            f.write(revFile + "\n\n")
        return None
    except Exception as e:
        errorPath = os.path.join(Configuration.OUTPUT_PATH, "ParseErrorMessage.log")
        with open(errorPath, 'a+') as f:
            f.write("ParseError:\n")
            f.write(prevFile + "\n")
            f.write(revFile + "\n\n")
        return None

def gumtreeDiff(prevFile, revFile):
    if not jpype.isJVMStarted():startJVM()
    gumtreeRun = jpype.JClass("com.github.gumtreediff.client.Run")
    result = gumtreeRun.main(["textdiff", prevFile, revFile])

    return result