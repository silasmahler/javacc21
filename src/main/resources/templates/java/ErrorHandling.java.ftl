[#ftl strict_vars=true]
[#--
/* Copyright (c) 2020 Jonathan Revusky, revusky@javacc.com
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
 *       nor the names of any contributors may be used to endorse 
 *       or promote products derived from this software without specific prior written 
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
 --]
 [#if grammar.options.debugParser]
  private boolean trace_enabled = true;
 [#else]
  private boolean trace_enabled = false;
 [/#if]
 
  public void setTracingEnabled(boolean tracingEnabled) {trace_enabled = tracingEnabled;}
  
 /**
 * @deprecated Use #setTracingEnabled
 */
   @Deprecated
  public void enable_tracing() {
    setTracingEnabled(true);
  }

/**
 * @deprecated Use #setTracingEnabled
 */
@Deprecated
 public void disable_tracing() {
    setTracingEnabled(false);
  }
 
ArrayList<NonTerminalCall> parsingStack = new ArrayList<>();
private ArrayList<NonTerminalCall> lookaheadStack = new ArrayList<>();


private EnumSet<TokenType> currentFollowSet;

/**
 * Inner class that represents entering a grammar production
 */
class NonTerminalCall {
    final String sourceFile;
    final String productionName;
    final int line, column;

    NonTerminalCall(String sourceFile, String productionName, int line, int column) {
        this.sourceFile = sourceFile;
        this.productionName = productionName;
        this.line = line;
        this.column = column;
    }

    StackTraceElement createStackTraceElement() {
        return new StackTraceElement("${grammar.parserClassName}", productionName, sourceFile, line);
    }
}

private final void pushOntoCallStack(String methodName, String fileName, int line, int column) {
   parsingStack.add(new NonTerminalCall(fileName, methodName, line, column));
}

private final void popCallStack() {
    parsingStack.remove(parsingStack.size() -1);
}

private final void restoreCallStack(int prevSize) {
    while (parsingStack.size() > prevSize) {
       popCallStack();
    }
}

private Iterator<NonTerminalCall> stackIteratorForward() {
    final Iterator<NonTerminalCall> parseStackIterator = parsingStack.iterator();
    final Iterator<NonTerminalCall> lookaheadStackIterator = lookaheadStack.iterator();
    return new Iterator<NonTerminalCall>() {
        public boolean hasNext() {
            return parseStackIterator.hasNext() || lookaheadStackIterator.hasNext();
        }
        public NonTerminalCall next() {
            return parseStackIterator.hasNext() ? parseStackIterator.next() : lookaheadStackIterator.next();
        }
    };
}

private Iterator<NonTerminalCall> stackIteratorBackward() {
    final ListIterator<NonTerminalCall> parseStackIterator = parsingStack.listIterator(parsingStack.size());
    final ListIterator<NonTerminalCall> lookaheadStackIterator = lookaheadStack.listIterator(lookaheadStack.size());
    return new Iterator<NonTerminalCall>() {
        public boolean hasNext() {
            return parseStackIterator.hasPrevious() || lookaheadStackIterator.hasPrevious();
        }
        public NonTerminalCall next() {
            return lookaheadStackIterator.hasPrevious() ? lookaheadStackIterator.previous() : parseStackIterator.previous();
        }
    };
}


private final void pushOntoLookaheadStack(String methodName, String fileName, int line, int column) {
    lookaheadStack.add(new NonTerminalCall(fileName, methodName, line, column));
}

private final void popLookaheadStack() {
    lookaheadStack.remove(lookaheadStack.size() -1);
}

[#if grammar.options.faultTolerant]
    private boolean tolerantParsing= true;
    private boolean currentNTForced = false;
    private List<ParsingProblem> parsingProblems;
    // This is the last "legit" token consumed by the parsing machinery, not
    // a virtual or invalid Token inserted to continue parsing.
    
    public void addParsingProblem(ParsingProblem problem) {
        if (parsingProblems == null) {
            parsingProblems = new ArrayList<>();
        }
        parsingProblems.add(problem);
    }
    
    public List<ParsingProblem> getParsingProblems() {
        return parsingProblems;
    }
    
    public boolean hasParsingProblems() {
        return parsingProblems != null && !parsingProblems.isEmpty();
    }    

    private void resetNextToken() {
       current_token.setNext(null);
//       token_source.reset(current_token);
       token_source.reset(lastParsedToken);
  }
  
[#else]
    private final boolean tolerantParsing = false;
[/#if]
    public boolean isParserTolerant() {return tolerantParsing;}
    
    public void setParserTolerant(boolean tolerantParsing) {
      [#if grammar.options.faultTolerant]
        this.tolerantParsing = tolerantParsing;
      [#else]
        if (tolerantParsing) {
            throw new UnsupportedOperationException("This parser was not built with that feature!");
        } 
      [/#if]
    }

[#if grammar.options.faultTolerant]
    private Token insertVirtualToken(TokenType tokenType) {
        Token virtualToken = Token.newToken(tokenType, "VIRTUAL " + tokenType, this);
        virtualToken.setLexicalState(token_source.lexicalState);
        virtualToken.setUnparsed(true);
        virtualToken.setVirtual(true);
        int line = lastParsedToken.getEndLine();
        int column = lastParsedToken.getEndColumn();
        virtualToken.setBeginLine(line);
        virtualToken.setEndLine(line);
        virtualToken.setBeginColumn(column);
        virtualToken.setEndColumn(column);
     [#if grammar.lexerData.numLexicalStates >1]
         token_source.doLexicalStateSwitch(tokenType);
     [/#if]
        return virtualToken;
    }
  

     private Token consumeToken(TokenType expectedType) throws ParseException {
        return consumeToken(expectedType, false);
     }
 
     private Token consumeToken(TokenType expectedType, boolean forced) throws ParseException {
 [#else]
      private Token consumeToken(TokenType expectedType) throws ParseException {
        boolean forced = false;
 [/#if]
        InvalidToken invalidToken = null;
        Token oldToken = current_token;
        current_token = current_token.getNext();
        if (current_token == null ) {
            current_token = token_source.getNextToken();
        }
[#if grammar.options.faultTolerant]        
        if (tolerantParsing && current_token instanceof InvalidToken) {
             addParsingProblem(new ParsingProblem("Lexically invalid input", current_token));
             invalidToken = (InvalidToken) current_token;
             current_token = token_source.getNextToken();     
        }
[/#if]
        if (current_token.getType() != expectedType) {
            handleUnexpectedTokenType(expectedType, forced, oldToken) ;
        }
        else {
            this.lastParsedToken = current_token;
        }
[#if grammar.options.treeBuildingEnabled]
      if (buildTree && tokensAreNodes) {
  [#if grammar.options.userDefinedLexer]
          current_token.setInputSource(inputSource);
  [/#if]
  [#if grammar.usesjjtreeOpenNodeScope]
          jjtreeOpenNodeScope(current_token);
  [/#if]
  [#if grammar.usesOpenNodeScopeHook]
          openNodeScopeHook(current_token);
  [/#if]
          if (invalidToken != null) {
             pushNode(invalidToken);
          }          
          pushNode(current_token);
  [#if grammar.usesjjtreeCloseNodeScope]
          jjtreeCloseNodeScope(current_token);
  [/#if]
  [#if grammar.usesCloseNodeScopeHook]
          closeNodeScopeHook(current_token);
  [/#if]
      }
[/#if]
      if (trace_enabled) LOGGER.info("Consumed token of type " + current_token.getType() + " from " + current_token.getLocation());
      return current_token;
  }
 
  private void handleUnexpectedTokenType(TokenType expectedType,  boolean forced, Token oldToken) throws ParseException {
[#if grammar.options.faultTolerant]    
       if (forced && tolerantParsing) {
           Token nextToken = current_token;
           current_token = oldToken;
           Token virtualToken = insertVirtualToken(expectedType);
           virtualToken.setNext(nextToken);
           current_token = virtualToken;
           String message = "Expecting token type "+ expectedType + " but encountered " + nextToken.getType();
           message += "\nInserting virtual token to continue parsing";
           addParsingProblem(new ParsingProblem(message, virtualToken));
       } else 
[/#if]      
       throw new ParseException(current_token, EnumSet.of(expectedType), parsingStack);
  }
  
 [#if !grammar.options.hugeFileSupport && !grammar.options.userDefinedLexer]
 
  private class ParseState {
       Token lastParsed;
  [#if grammar.options.treeBuildingEnabled]
       NodeScope nodeScope;
 [/#if]       
       ParseState() {
           this.lastParsed  = ${grammar.parserClassName}.this.lastParsedToken;
[#if grammar.options.treeBuildingEnabled]            
           this.nodeScope = (NodeScope) currentNodeScope.clone();
[/#if]           
       } 
  }

 private ArrayList<ParseState> parseStateStack = new ArrayList<>();
 
  void stashParseState() {
      parseStateStack.add(new ParseState());
  }
  
  ParseState popParseState() {
      return parseStateStack.remove(parseStateStack.size() -1);
  }
  
  void restoreStashedParseState() {
     ParseState state = popParseState();
[#if grammar.options.treeBuildingEnabled]
     currentNodeScope = state.nodeScope;
[/#if]
    if (state.lastParsed != null) {
        //REVISIT
        current_token = lastParsedToken = state.lastParsed;
    }
[#if grammar.lexerData.numLexicalStates > 1]     
     token_source.switchTo(lastParsedToken.getLexicalState());
     if (token_source.doLexicalStateSwitch(lastParsedToken.getType())) {
         token_source.reset(lastParsedToken);
         lastParsedToken.setNext(null);
     }
[/#if]          
  } 
  
  [/#if] 