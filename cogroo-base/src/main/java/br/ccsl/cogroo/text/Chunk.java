package br.ccsl.cogroo.text;

import opennlp.tools.util.Span;

public interface Chunk {
  
  public Span getSpan();
  
  public void setSpan(Span span);
  
  public void setHeadIndex(int index);
}
