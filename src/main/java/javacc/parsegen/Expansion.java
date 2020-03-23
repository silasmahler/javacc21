/* Copyright (c) 2008-2020 Jonathan Revusky, revusky@javacc.com
 * Copyright (c) 2006, Sun Microsystems Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright notices,
 *       this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name Jonathan Revusky, Sun Microsystems, Inc.
 *       nor the names of any contributors may be used to endorse or promote
 *       products derived from this software without specific prior written
 *       permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

package javacc.parsegen;

import javacc.Grammar;
import javacc.parser.BaseNode;
import javacc.lexgen.RegularExpression;
import javacc.parser.tree.TreeBuildingAnnotation;
import javacc.parser.tree.ParserProduction;



/**
 * Describes expansions - entities that may occur on the right hand sides of
 * productions. This is the base class of a bunch of other more specific
 * classes.
 */

abstract public class Expansion extends BaseNode {

    private boolean forced;

    private TreeBuildingAnnotation treeNodeBehavior;

    private Lookahead lookahead;

    public Expansion(Grammar grammar) {
        setGrammar(grammar);
    }

    public Expansion() {}

    /**
     * The ordinal of this node with respect to its parent.
     */
    public int index;
    
    private int ordinal= -1; // REVISIT
    
    private String phase2RoutineName, phase3RoutineName;

    public long myGeneration = 0;

    /**
     * This flag is used for bookkeeping by the minimumSize method in class
     * ParseEngine.
     */
    boolean inMinimumSize = false;

    private String getSimpleName() {
        String name = getClass().getName();
        return name.substring(name.lastIndexOf(".") + 1); // strip the package name
    }
    
    public String toString() {
    	return "[" + getSimpleName() + " expansion on line " + getBeginLine() + ", " + getBeginColumn() + "of " + this.getInputSource() + "]";
    }

    protected static final String eol = System.getProperty("line.separator", "\n");

    public Expansion getNestedExpansion() {
        return null;
    }

    public boolean getIsRegexp() {
        return (this instanceof RegularExpression);
    }
    
    public TreeBuildingAnnotation getTreeNodeBehavior() {
        if (treeNodeBehavior == null) {
            if (this.getParent() instanceof ParserProduction) {
                return ((ParserProduction) getParent()).getTreeNodeBehavior();
            }
        }
        return treeNodeBehavior;
    }

    public void setTreeNodeBehavior(TreeBuildingAnnotation treeNodeBehavior) {
        if (getGrammar().getOptions().getTreeBuildingEnabled()) {
            this.treeNodeBehavior = treeNodeBehavior;
            if (treeNodeBehavior != null) {
                getGrammar().addNodeType(treeNodeBehavior.getNodeName());
            }
        }
    }

    public void setLookahead(Lookahead lookahead) {
    	this.lookahead = lookahead;
    }

    public Lookahead getLookahead() {
    	return lookahead;
    }

    public void setForced(boolean forced) {this.forced = forced;}

    public boolean getForced() {return this.forced;}
    
    public void setOrdinal(int ordinal) { this.ordinal = ordinal;}
    
    public int getOrdinal() {return this.ordinal;}
    
    public void setPhase2RoutineName(String name) {
    	this.phase2RoutineName = name;
    }

    public String getPhase2RoutineName() {
    	return this.phase2RoutineName;
    }
    
    public void setPhase3RoutineName(String name) {
    	this.phase3RoutineName = name;
    }

    public String getPhase3RoutineName() {
    	return phase3RoutineName != null ? phase3RoutineName : getPhase2RoutineName().replace("phase2", "phase3");
    }
    
    
    public void genFirstSet(boolean[] firstSet) {
    	    Expansion nestedExpansion = getNestedExpansion();
    	    if (nestedExpansion != null) {
    	    	nestedExpansion.genFirstSet(firstSet);
    	    }
    }
}