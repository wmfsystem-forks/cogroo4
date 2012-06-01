package br.ccsl.cogroo.text.tree;

import java.util.ArrayList;
import java.util.List;

import br.ccsl.cogroo.text.Chunk;
import br.ccsl.cogroo.text.Sentence;
import br.ccsl.cogroo.text.SyntacticChunk;
import br.ccsl.cogroo.text.Token;

public class TreeUtil {

  public static Node createTree(Sentence sent) {
    Node root = new Node();
    root.setLevel(0);
    root.setSyntacticTag("S");

    List<TreeElement> elements = createLeafsList(sent);
    TreeElement[] originalElements = elements.toArray(new TreeElement[elements
        .size()]);

    List<Token> tokens = sent.getTokens();
    List<Chunk> chunks = sent.getChunks();
    List<SyntacticChunk> syntChunks = sent.getSyntacticChunks();

    for (int i = chunks.size() - 1; i >= 0; i--) {
      Node node = new Node();

      node.setSyntacticTag(chunks.get(i).getTag());
      node.setMorphologicalTag(null);
      node.setLevel(2);

      for (int j = chunks.get(i).getStart(); j < chunks.get(i).getEnd(); j++) {
        // System.out.println("coloquei" + elements.get(j));
        node.addElement(elements.get(j));
        elements.get(j).setParent(node);
      }

      for (int j = chunks.get(i).getEnd() - 1; j >= chunks.get(i).getStart(); j--) {
        // System.out.println("Vou remover " + elements.get(j));
        elements.remove(j);
      }

      elements.add(chunks.get(i).getStart(), node);
    }

    for (int i = 0; i < syntChunks.size(); i++) {
      Node node = new Node();

      node.setSyntacticTag(syntChunks.get(i).getTag());
      node.setMorphologicalTag(null);
      node.setLevel(1);
      
      List<TreeElement> toRemove = new ArrayList<TreeElement>();
      
      for (int j = syntChunks.get(i).getEnd()-1; j >= syntChunks.get(i).getStart(); j--) {
        if (originalElements[j].getParent() == null) {
          node.addElement(originalElements[j]);
          toRemove.add(originalElements[j]);
        } else {

          if (node.getElements().length == 0
              || node.getElements()[node.getElements().length - 1] != originalElements[j]
                  .getParent()) {
            node.addElement(originalElements[j].getParent());
            toRemove.add(originalElements[j].getParent());
          }
        }
      }
      
      int index = elements.indexOf(toRemove.get(toRemove.size()-1));
      
      for (TreeElement element : toRemove) {
        
        elements.remove(element);
        
      }
      elements.add(index, node);
      
      node.setParent(root);
    }
    
    for (TreeElement element : elements) {
      root.addElement(element);
    }

    return root;
  }

  public static List<TreeElement> createLeafsList(Sentence sentence) {
    List<TreeElement> leafs = new ArrayList<TreeElement>();

    List<Token> tokens = sentence.getTokens();

    for (Token token : tokens) {
      Leaf leaf = new Leaf(token.getLexeme(), token.getLemmas());
      leaf.setLevel(3);
      leafs.add(leaf);
    }

    return leafs;
  }

}
