export const monkeysGrammar = {
	name: 'monkeys',
	scopeName: 'source.monkeys',
	patterns: [
		{ name: 'comment.line.number-sign.monkeys', match: '#.*$' },
		{ name: 'keyword.control.namespace.monkeys', match: '^\\+[A-Za-z0-9_.-]+' },
		{ name: 'entity.name.tag.profile.monkeys', match: '^@[A-Za-z0-9_.-]+(,[A-Za-z0-9_.-]+)*' },
		{ name: 'variable.other.constant.monkeys', match: '^[A-Za-z_][A-Za-z0-9_]*' }
	],
	repository: {}
};
