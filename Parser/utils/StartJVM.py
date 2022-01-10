import jpype
import Configuration

def startJVM():
    jarPath = Configuration.GUMTREE_JAR_PATH
    jpype.startJVM(classpath=jarPath)