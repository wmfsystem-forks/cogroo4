/**
 * Copyright (C) 2012 cogroo <cogroo@cogroo.org>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.cogroo.dictionary;

public interface AbbreviationDictionaryI {

	/**
	 * Checks if this dictionary has the given entry.
	 * 
	 * @param token
	 *            the token to query
	 * 
	 * @return true if it contains the entry otherwise false
	 */
	public abstract boolean contains(String tokens);

}